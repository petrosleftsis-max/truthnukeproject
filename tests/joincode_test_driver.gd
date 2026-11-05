extends Node
## Join codes (Net "Join codes"; the designer, 2026-11-05): an address and port packed into
## something to read out or paste. `net` joins by one, across two machines; this is what
## they come to, on their own.

var LOG_PATH := HarnessLog.path_for("joincode")
var _log: FileAccess = null
var _fail := 0


func log_line(text: String):
	if _log:
		_log.store_line(text)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(60.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var code := Net.code_for("192.168.1.5")
	ok(code.length() == 9 and code[4] == "-", "the usual port: eight characters, as K7QF-2MXA", code)
	ok(Net.read_code(code) == {"address": "192.168.1.5", "port": Net.PORT}, "and it comes back", "%s" % [Net.read_code(code)])
	var with_port := Net.code_for("203.0.113.77", 24790)
	ok(with_port.length() > code.length(), "another port makes it longer", with_port)
	ok(Net.read_code(with_port) == {"address": "203.0.113.77", "port": 24790}, "and comes back", "%s" % [Net.read_code(with_port)])
	ok(Net.read_code(Net.code_for("203.0.113.77:24790")) == {"address": "203.0.113.77", "port": 24790}, "an address with its port, as the panel gives it")
	# Every byte, either end.
	var round_trips := true
	for address in ["0.0.0.0", "255.255.255.255", "10.0.0.1", "127.0.0.1", "100.64.12.200"]:
		for port in [Net.PORT, 1, 65535, 24790]:
			var back := Net.read_code(Net.code_for(address, port))
			if back.get("address") != address or back.get("port") != port:
				round_trips = false
				log_line("  (%s:%d came back %s)" % [address, port, back])
	ok(round_trips, "any address and port come back")
	# Read out and typed back any old way.
	ok(Net.read_code(code.to_lower()) == Net.read_code(code), "lower case")
	ok(Net.read_code(code.replace("-", " ")) == Net.read_code(code) and Net.read_code(code.replace("-", "")) == Net.read_code(code), "with a space, or without the dash")
	ok(not Net.CODE_LETTERS.contains("O") and not Net.CODE_LETTERS.contains("I") and not Net.CODE_LETTERS.contains("L"), "no letter to mix up with a number")
	ok(Net.read_code(code.replace("0", "O").replace("1", "I")) == Net.read_code(code), "and an O or an I taken for what was meant")
	# What is not a code.
	var wrong: String = ("A" if code[0] != "A" else "B") + code.substr(1)
	ok(Net.read_code(wrong).is_empty(), "a mistyped one is no code", wrong)
	for text in ["192.168.1.5", "localhost", "my-pc.local", "", "hello"]:
		ok(Net.read_code(text).is_empty(), "'%s' is an address, not a code" % text)
	ok(Net.code_for("::1") == "" and Net.code_for("not an address") == "", "nothing but an IPv4 address has one")
	# The panel: a code beside each address, and the box takes either.
	var panel := NetPanel.new()
	get_tree().root.add_child(panel)
	await get_tree().process_frame
	ok(panel._address.placeholder_text.contains("Code"), "the box says it takes a code", panel._address.placeholder_text)
	panel.queue_free()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
