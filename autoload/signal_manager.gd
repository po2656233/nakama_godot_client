extends Node
# 新消息
@warning_ignore("unused_signal")
signal NewMessageSIG(args)
# 新通知
@warning_ignore("unused_signal")
signal NewNotifySIG(args)
# 新邮件
@warning_ignore("unused_signal")
signal NewEmailSIG(args)


# 发送消息
@warning_ignore("unused_signal")
signal SendMessageSIG(args)
# 接收消息
@warning_ignore("unused_signal")
signal RecvMessageSIG(args)
# 上线
@warning_ignore("unused_signal")
signal OnlineSIG()


# 添加好友
@warning_ignore("unused_signal")
signal AddFriendSIG(args) 
# 删除好友
@warning_ignore("unused_signal")
signal DeleteFriendSIG(uid) 
# 刷新好友列表
@warning_ignore("unused_signal")
signal FreshFriendListSIG()


# 添加俱乐部
@warning_ignore("unused_signal")
signal AddClubSIG(args) 
# 更新俱乐部信息
@warning_ignore("unused_signal")
signal UpdateClubSIG(gName) 
# 删除俱乐部
@warning_ignore("unused_signal")
signal DeleteClubSIG(gid) 
# 刷新俱乐部列表
@warning_ignore("unused_signal")
signal FreshClubListSIG() 

# 开灯
@warning_ignore("unused_signal")
signal OpenLightSIG() 
# 关灯
@warning_ignore("unused_signal")
signal CloseLightSIG() 

# 静音
@warning_ignore("unused_signal")
signal MuteSIG(isMute)
# 背景音乐
@warning_ignore("unused_signal")
signal backgroundMusicSIG(isMute)
# 背景音乐
@warning_ignore("unused_signal")
signal gameMusicSIG(id,isMute)