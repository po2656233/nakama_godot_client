extends Node

var peer: WebRTCPeerConnection
var multiplayer_peer: WebRTCMultiplayerPeer
var camera_texture: ViewportTexture

func _ready():
	# 创建 WebRTC 多人连接
	multiplayer_peer = WebRTCMultiplayerPeer.new()
	
	# 创建对等连接
	peer = WebRTCPeerConnection.new()
	
	# 设置 ICE 服务器
	var ice_servers = {
		"iceServers": [
			{ "urls": ["stun:stun.l.google.com:19302"] }
		]
	}
	
	# 初始化对等连接
	var error = peer.initialize(ice_servers)
	if error != OK:
		print("Failed to initialize peer connection")
		return
	
	# 连接信号
	peer.connect("session_description_created", _on_session_description_created)
	peer.connect("ice_candidate_created", _on_ice_candidate_created)
	
	# 创建本地视频流
	var init_result = multiplayer_peer.create_mesh({
		"video": true,  # 启用视频
		"audio": false  # 不需要音频
	})
	
	if init_result == OK:
		print("Successfully initialized video stream")
		multiplayer_peer.connect("peer_connected", _on_peer_connected)
		multiplayer_peer.connect("peer_disconnected", _on_peer_disconnected)
	else:
		print("Failed to initialize video stream")

func _on_session_description_created(type: String, sdp: String) -> void:
	# 设置本地描述
	peer.set_local_description(type, sdp)

func _on_ice_candidate_created(media: String, index: int, name: String) -> void:
	# 处理新的 ICE 候选者
	print("New ICE candidate: ", name)

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	# 获取视频流并显示
	var video_stream = multiplayer_peer.get_peer(id).get_video_stream()
	if video_stream:
		$TextureRect.texture = video_stream
		print("Video stream received")

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	$TextureRect.texture = null

func _exit_tree() -> void:
	if multiplayer_peer:
		multiplayer_peer.close()
	if peer:
		peer.close()

# 切换摄像头
func switch_camera() -> void:
	if multiplayer_peer:
		# 切换视频源
		multiplayer_peer.create_mesh({
			"video": true,
			"audio": false,
			"video_source": "environment" if multiplayer_peer.get_video_source() == "user" else "user"
		})
