extends Node
# # 信号量
var counter :int = 0
var mutex: Mutex
var semaphore: Semaphore
var thread: Thread
var exit_thread :bool = false


func startThread():
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	exit_thread = false
	thread = Thread.new()
	thread.start(_thread_function)

func _thread_function():
	while true:
		semaphore.wait() # Wait until posted.
		mutex.lock()
		var should_exit = exit_thread # Protect with Mutex.
		mutex.unlock()
		if should_exit:
			break
		mutex.lock()
		counter += 1
		mutex.unlock()

func toWork():
	semaphore.post()

func get_counter():
	mutex.lock()
	# Copy counter, protect with Mutex.
	var counter_value = counter
	mutex.unlock()
	return counter_value

# Thread must be disposed (or "joined"), for portability.
func _exit_tree():
	# Set exit condition to true.
	mutex.lock()
	exit_thread = true # Protect with Mutex.
	mutex.unlock()
	# Unblock by posting.
	semaphore.post()
	# Wait until it exits.
	thread.wait_to_finish()
	# Print the counter.
	print("Counter is: ", counter)
