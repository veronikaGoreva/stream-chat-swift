//
//  Client+UnreadCount.swift
//  StreamChatClient
//
//  Created by Alexey Bukhtin on 29/01/2020.
//  Copyright © 2020 Stream.io Inc. All rights reserved.
//

import Foundation

extension Client {
    
    // MARK: User Unread Count
    
    func updateUserUnreadCount(with event: Event) {
        var updatedChannelsUnreadCount = -1
        var updatedMssagesUnreadCount = -1
        
        switch event {
        case let .notificationAddedToChannel(_, channelsUnreadCount, messagesUnreadCount, _),
             let .notificationMarkRead(_, channelsUnreadCount, messagesUnreadCount, _, _):
            updatedChannelsUnreadCount = channelsUnreadCount
            updatedMssagesUnreadCount = messagesUnreadCount
        case let .messageNew(_, channelsUnreadCount, messagesUnreadCount, _, _, eventType):
            if case .notificationMessageNew = eventType {
                updatedChannelsUnreadCount = channelsUnreadCount
                updatedMssagesUnreadCount = messagesUnreadCount
            }
        default:
            break
        }
        
        if updatedChannelsUnreadCount != -1 {
            user.channelsUnreadCountAtomic.set(updatedChannelsUnreadCount)
            user.messagesUnreadCountAtomic.set(updatedMssagesUnreadCount)
            userDidUpdate?(user)
        }
    }
    
    // MARK: Channel Unread Count
    
    func updateChannelsUnreadCount(with event: Event) {
        channels.flush()
        
        channels.forEach {
            if let channel = $0.value {
                updateChannelUnreadCount(channel: channel, event: event)
            }
        }
    }
    
    /// Update the unread count if needed.
    /// - Parameter response: a web socket event.
    func updateChannelUnreadCount(channel: Channel, event: Event) {
        let oldUnreadCount = channel.unreadCountAtomic.get(default: 0)
        
        guard let cid = event.cid, cid == channel.cid else {
            if case .notificationMarkRead(let notificationChannel, let unreadCount, _, _, _) = event,
                notificationChannel?.cid == channel.cid {
                channel.unreadCountAtomic.set(unreadCount)
                channel.didUpdate?(channel)
            }
            
            return
        }
        
        if case let .messageNew(message, unreadCount, _, _, _, eventType) = event, case .messageNew = eventType {
            channel.unreadCountAtomic.set(unreadCount)
            updateUserUnreadCountForChannelUpdate(channelsDiff: oldUnreadCount == 0 ? 1 : 0,
                                                  messagesDiff: unreadCount - oldUnreadCount)
            
            if message.user != user, message.mentionedUsers.contains(user) {
                channel.mentionedUnreadCountAtomic += 1
            }
            
            channel.didUpdate?(channel)
            return
        }
        
        if case .messageRead(let messageRead, _, _) = event, messageRead.user.isCurrent {
            channel.unreadCountAtomic.set(0)
            channel.mentionedUnreadCountAtomic.set(0)
            channel.didUpdate?(channel)
            updateUserUnreadCountForChannelUpdate(channelsDiff: oldUnreadCount > 0 ? -1 : 0, messagesDiff: -oldUnreadCount)
            return
        }
    }
    
    private func updateUserUnreadCountForChannelUpdate(channelsDiff channels: Int, messagesDiff messages: Int) {
        // Update user unread counts.
        if channels != 0  {
            user.channelsUnreadCountAtomic += channels
        }
        
        user.messagesUnreadCountAtomic += messages
        userDidUpdate?(user)
    }
}
