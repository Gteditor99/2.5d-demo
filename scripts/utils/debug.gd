extends Node

# Centralized logging utility to be used as an autoload singleton.

# Enum to define log levels.
enum LogLevel {
	INFO,
	WARNING,
	ERROR
}

# Set the current log level.
var current_log_level: LogLevel = LogLevel.INFO

# --- Public Methods ---

# Logs a message to the console with a high-precision timestamp.
func log(message: String, level: LogLevel = LogLevel.INFO):
	if level >= current_log_level:
		var timestamp = Time.get_ticks_usec()
		var formatted_message = "[%d] [%s] %s" % [timestamp, _get_log_level_string(level), message]
		print(formatted_message)

# --- Private Methods ---

# Converts a LogLevel enum to a string.
func _get_log_level_string(level: LogLevel) -> String:
	match level:
		LogLevel.INFO:
			return "INFO"
		LogLevel.WARNING:
			return "WARNING"
		LogLevel.ERROR:
			return "ERROR"
		_:
			return "UNKNOWN"