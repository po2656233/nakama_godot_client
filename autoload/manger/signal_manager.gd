extends Node
# 信号管理器
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
# 接收完全部消息
@warning_ignore("unused_signal")
signal RecvFinishSIG()
# 上线
@warning_ignore("unused_signal")
signal OnlineSIG()

# 欢迎
@warning_ignore("unused_signal")
signal WelcomeMusicSIG()
###################社交###########################
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

##################系统############################
# 开灯
@warning_ignore("unused_signal")
signal OpenLightSIG() 
# 关灯
@warning_ignore("unused_signal")
signal CloseLightSIG() 

# 全屏化
@warning_ignore("unused_signal")
signal FullWindowSIG() 
# 正常化
@warning_ignore("unused_signal")
signal NormalWindowSIG() 
# 最小化
@warning_ignore("unused_signal")
signal SmallWindowSIG() 

# 静音
@warning_ignore("unused_signal")
signal MuteSIG(isMute)
# 背景音乐
@warning_ignore("unused_signal")
signal BackgroundMusicSIG(isMute)
# 游戏音乐
@warning_ignore("unused_signal")
signal GameMusicSIG(id,isMute)

# 加载
@warning_ignore("unused_signal")
signal LoadingSIG(value) 

# 切换场景
@warning_ignore("unused_signal")
signal ChangeSceneSIG(sceneName, transition_way, dissolve_time, dissolve_image) 

####################游戏#############################
# 加载游戏
@warning_ignore("unused_signal")
signal LoadingGameSIG(gameName) 
# 加入游戏
@warning_ignore("unused_signal")
signal JoinGameSIG(gid) 
# 离开游戏
@warning_ignore("unused_signal")
signal LeaveGameSIG(gid) 
# 开始游戏
@warning_ignore("unused_signal")
signal StartGameSIG(gid) 
# 取消游戏
@warning_ignore("unused_signal")
signal CancleGameSIG(gid) 
# 退出游戏
@warning_ignore("unused_signal")
signal ExitGameSIG(gid) 
# 开始游戏
@warning_ignore("unused_signal")
signal GameKeepSIG(mode,gid,rid,mid,gname) 
####################房间##############################
# 创建房间
@warning_ignore("unused_signal")
signal CreateRoomSIG(rid) 
# 删除房间
@warning_ignore("unused_signal")
signal RemoveRoomSIG(rid) 
# 加入房间
@warning_ignore("unused_signal")
signal JoinRoomSIG(rid) 
# 退出房间
@warning_ignore("unused_signal")
signal LeaveRoomSIG(rid) 
# 房间满员
@warning_ignore("unused_signal")
signal FullRoomSIG(rid) 

# 加入房间失败
@warning_ignore("unused_signal")
signal JoinErrorMusicSIG(rid)
# 加入房间成功
@warning_ignore("unused_signal")
signal JoinSuccessMusicSIG(rid) 

# 桌子上的在线人数
@warning_ignore("unused_signal")
signal OnlineCountSIG(count) 
###################事件###################################
# 匹配事件
@warning_ignore("unused_signal")
signal MatchPresenceEventSIG(evt) 
# 匹配事件
@warning_ignore("unused_signal")
signal MatchMakerSIG(evt) 
# 匹配状态
@warning_ignore("unused_signal")
signal MatchStateEventSIG(evt) 
# 玩家状态事件
@warning_ignore("unused_signal")
signal StatusPresenceEventSIG(evt) 
###################匹配###################################
# 匹配失败
@warning_ignore("unused_signal")
signal MatchMakerFailedSIG() 

# 正在匹配的成功音效
@warning_ignore("unused_signal")
signal MatchingOkMusicSIG() 
# 正在匹配的取消音效
@warning_ignore("unused_signal")
signal MatchingFailedMusicSIG() 
# 正在匹配的时间音效
@warning_ignore("unused_signal")
signal MatchingTimeMusicSIG(isStop) 

# 匹配成功的成功音效
@warning_ignore("unused_signal")
signal MatchSuccessOkMusicSIG() 
# 匹配成功的取消音效
@warning_ignore("unused_signal")
signal MatchSuccessFailedMusicSIG() 
# 匹配成功的时间音效
@warning_ignore("unused_signal")
signal MatchSuccessTimeMusicSIG(isStop) 
