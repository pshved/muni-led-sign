# Backport of the ruby 1.9's open3 to 1.8

module EnhancedOpen3

	# Aside from a usual stuff, you may specify a :fork_callback option
	def popen3(*cmd, &block)
		if Hash === cmd.last
			opts = cmd.pop.dup
		else
			opts = {}
		end

		in_r, in_w = IO.pipe
		opts[:in] = in_r
		in_w.sync = true

		out_r, out_w = IO.pipe
		opts[:out] = out_w

		err_r, err_w = IO.pipe
		opts[:err] = err_w

		popen_run(cmd, opts, [in_r, out_w, err_w], [in_w, out_r, err_r], &block)
	end
	module_function :popen3

	def popen_run(cmd, opts, child_io, parent_io) # :nodoc:
		# Backport: merge opts and cmd
		cmop = cmd.dup.push opts 
		pid = fork{
			# Since we inherited all filehandlers, we should close those that belong to the parent
			parent_io.each {|io| io.close}
			# child
			STDIN.reopen(opts[:in])
			STDOUT.reopen(opts[:out])
			STDERR.reopen(opts[:err])

			opts[:fork_callback].call if opts[:fork_callback]

			exec(*cmd)
		}
		wait_thr = Process.detach(pid)
		# Save PID in thread to comply to Ruby1.9-like api.  Crazy, huh?
		wait_thr[:pid]=pid
		child_io.each {|io| io.close }
		result = parent_io.dup.push wait_thr
		if defined? yield
			begin
				return yield(*result)
			ensure
				parent_io.each{|io| io.close unless io.closed?}
				wait_thr.join
			end
		end
		result
	end
	module_function :popen_run
	class << self
		private :popen_run
	end

	# Open a stream with open3, and invoke a callback when a stream is ready for reading (but may be in EOF mode).  Waits till the process terminates, and returns its error code.  Callbacks should not block for FDs with data available.
	def open3_callbacks(cin_callback, cout_callback, cerr_callback, *args)
		code = nil
		popen3(*args) do |cin,cout,cerr,thr|
			pid = thr[:pid]
			# Close input at once, if we don't use it
			if cin_callback
				in_ss = [cin]
			else
				in_ss = nil
				cin.close_write
			end
			# If the End-Of-File is reached on all of the streams, then the process might have already ended
			non_eof_streams = [cerr,cout]
			# Progressive timeout.  We assume that probability of task to be shorter is greater than for it to be longer.  So we increase timeout interval of select, as with time it's less likely that a task will die in the fixed interval.
			sleeps = [ [0.05]*20,[0.1]*5,[0.5]*3,1,2,4].flatten
			while non_eof_streams.length > 0
				# Get next timeout value from sleeps array until none left
				timeout = sleeps.shift || timeout
				r = select(non_eof_streams,in_ss,nil,timeout)
				# If nothing happened during a timeout, check if the process is alive.
				# Perhaps, it's dead, but the pipes are still open,  This actually happened by sshfs process, which spawns a child and dies, but the child inherits the in-out-err streams, and does not close them.
				unless r
					if thr.alive?
						# The process is still running, no paniv
						next
					else
						# The process is dead.  We consider that it won't print anymore, and thus the further polling the pipes will only lead to a hangup.  Thus, breaking.
						break
					end
				end
				if r[1].include? cin
					begin
						# If cin_callback is nil, we wouldn't have get here: cin is instantly closed before polling; see above
						case cin_callback[pid,cin]
						when :close
							# Close the output
							cin.close_write
							in_ss = []
						when :detach
							# Do not close, but do not poll as well
							in_ss = []
						# Otherwise, we have written something to CIN, do nothnig
						end
					rescue EOFError
						in_ss = []
					end
				end
				if r[0].include? cerr
					begin
						cerr_callback[pid,cerr]
						# TODO: in_ss should be filled after callback succeedes
					rescue EOFError
						non_eof_streams.delete_if {|s| s==cerr}
					end
				end
				if r[0].include? cout
					begin
						cout_callback[pid,cout]
						# TODO: in_ss should be filled after callback succeedes
					rescue EOFError
						non_eof_streams.delete_if {|s| s==cout}
					end
				end
			end
			cin.close_write if in_ss && !in_ss.empty?
			# Reap process status
			# NOTE: in the ruby 1.8.7 I used this line may block for up to a second (due to internal thread scheduling machanism of Ruby).  In 1.9 this waitup is gone.  Upgrade your software if you encounter differences.
			code = thr.value
		end
		# Return code, either nil if something bad happened, or the actual return code if we were successful
		code
	end
	module_function :open3_callbacks

	# Read linewise and supply lines to callbacks
	# Linewise read can not use "readline" because the following situation may (and did) happen.  The process spawned writes some data to stderr, but does not terminate it with a newline.  We run a callback for stderr, use readline and block.  The process spawned then writes a lot of data to stdout, reaches pipe limit, and blocks as well in a write(stdout) call.  Deadlock.  So, we use more low-level read.
	# No returns are allowed in callbacks (ruby 1.9)
	def open3_linewise(cin_callback, cout_callback, cerr_callback, *args)
		# Read this number of bytes from stream per nonblocking read
		some = 4096

		# Standard output backend
		cout_buf = ''
		cout_backend = proc do |pid,cout|
			cout_buf += cout.readpartial some
			while md = /(.*)\n/.match(cout_buf)
				#$stderr.puts "feed: #{md[1]}"
				cout_callback[md[1]]
				cout_buf = md.post_match
			end
		end

		# standard error backend
		cerr_buf = ''
		cerr_backend = proc do |pid,cerr|
			cerr_buf += cerr.readpartial some
			while md = /(.*)\n/.match(cerr_buf)
				#$stderr.puts "feed: #{md[1]}"
				cerr_callback[md[1]]
				cerr_buf = md.post_match
			end
		end

		# standard input backend
		cin_buf = ''
		# cin_status may be :read (call the procedure and get string or a new status), or :close (close stdin and do not call the proc anymore), or :detach (do not close cin, and do not handle it anymore: something else will close it).
		cin_status = :read
		cin_backend = cin_callback.nil?? nil : proc do |pid,cin|
			# If the buffer is empty, call the procedure back
			# We intentionally supply the stream handler to the callback, as, most likely, the callback would like to access it directly
			if cin_buf.empty? && cin_status == :read
				cb = cin_callback[pid,cin]
				if cb.is_a? String
					cin_buf += cb
				else
					# Treat nil as :close
					cin_status = cb || :close
				end
			end
			# If the buffer is still empty, return nil, showing that cin is temporarly excluded from polling
			if cin_buf.empty? && cin_status != :read
				cin_status
			else
				# Something is in the buffer.  Print a portion of it.
				to_print, cin_buf = cin_buf[0..some-1],cin_buf[some..cin_buf.length-1]
				cin_buf ||= ''	# the previous line would null-ify the buffer if it's less than some
				#$stderr.puts "Length: to_print: #{to_print.length}, buf: #{cin_buf.length}"
				cin.write to_print
				:read
			end
		end

		retcode = open3_callbacks(cin_backend,cout_backend,cerr_backend,*args)

		# Read the rest of buffers
		cout_callback[cout_buf] if cout_buf.length > 0
		cerr_callback[cerr_buf] if cerr_buf.length > 0

		retcode
	end
	module_function :open3_linewise

	def open3_input_linewise(input_string,cout_callback,cerr_callback,*args)
		printed = false
		cin_callback = proc do
			#$stderr.puts "CB: #{printed}"
			if printed
				nil
			else
				printed = true
				input_string
			end
		end

		open3_linewise(cin_callback,cout_callback,cerr_callback,*args)
	end
	module_function :open3_input_linewise

end

