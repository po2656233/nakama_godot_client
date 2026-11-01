extends SceneTree
func _init() -> void:
	print("CameraServer feeds: ", CameraServer.get_feed_count())
	var t := CameraTexture.new()
	print("CameraTexture ok, props: ", t.get_property_list().filter(func(p): return p.name in ["camera_feed_id","which_feed"]).map(func(p): return p.name))
	print("FEED consts: ", CameraServer.FEED_RGBA_IMAGE, " ", CameraServer.FEED_YCBCR_IMAGE)
	print("AudioEffectCapture exists: ", ClassDB.class_exists("AudioEffectCapture"))
	print("AudioStreamMicrophone exists: ", ClassDB.class_exists("AudioStreamMicrophone"))
	quit(0)
