kd                = require 'kd'

whoami            = require '../util/whoami'
kookies           = require 'kookies'
getGroup          = require '../util/getGroup'
showError         = require '../util/showError'
Tracker           = require 'app/util/tracker'
remote            = require('../remote')
globals           = require 'globals'
GroupData         = require './groupdata'
remote_extensions = require 'app/remote-extensions'

module.exports = class GroupsController extends kd.Controller

  constructor: (options = {}, data) ->

    super options, data

    @isReady = no

    mainController    = kd.getSingleton 'mainController'
    { entryPoint }      = globals.config
    @groups           = {}
    @currentGroupData = new GroupData
    @currentGroupData.setGroup globals.currentGroup

    mainController.ready =>
      { slug } = entryPoint  if entryPoint?.type is 'group'
      @changeGroup slug

    @ready =>
      @on 'GroupDestroyed', ->
        # delete client id cookie, which is used for session authentication
        kookies.expire 'clientId'
        # send user to home page
        global.location.href = '/'

      @on 'InstanceChanged', (data) ->
        remote_extensions.updateInstance data?.contents

      @on 'InstanceDeleted', (data) ->
        remote_extensions.removeInstance data?.contents


  getCurrentGroup: ->
    FIXME = 'FIXME: array should never be passed'
    throw FIXME  if Array.isArray @currentGroupData.data
    return @currentGroupData.data


  currentGroupHasStack: ->

    { stackTemplates } = @getCurrentGroup()

    return stackTemplates?.length > 0


  currentGroupIsNew: -> not @getCurrentGroup().sharedStackTemplates


  filterXssAndForwardEvents: (target, events) ->
    events.forEach (event) =>
      target.on event, (rest...) =>
        rest = remote.revive rest
        @emit event, rest...

  openGroupChannel: (group, callback = -> ) ->
    @groupChannel = remote.subscribe "group.#{group.slug}",
      serviceType : 'group'
      group       : group.slug
      isExclusive : yes

    @filterXssAndForwardEvents @groupChannel, [
      'MemberJoinedGroup'
      'LikeIsAdded'
      'PostIsCreated'
      'ReplyIsAdded'
      'PostIsDeleted'
      'LikeIsRemoved'
    ]

    @groupChannel.once 'setSecretNames', callback


  openSocialGroupChannel: (group, callback = -> ) ->
    { realtime, socialapi } = kd.singletons

    socialapi.channel.byId { id: group.socialApiChannelId }, (err, channel) =>
      return callback err  if err

      socialapi.registerAndOpenChannel group, channel, (err, registeredChan) =>
        return callback err  if err

        realtimeChan = registeredChan?.delegate

        return callback 'realtime chan is not set'  unless realtimeChan

        @filterXssAndForwardEvents realtimeChan, [
          'StackTemplateChanged'
          'GroupStackTemplateRemoved'
          'InstanceChanged'
          'InstanceDeleted'
          'GroupDestroyed'
          'GroupJoined'
          'GroupLeft'
          'StackAdminMessageCreated'
          'ShareStackTemplate'
          'UnshareStackTemplate'
        ]

        callback null

  changeGroup: (groupName = 'koding', callback = kd.noop) ->

    return callback()  if @currentGroupName is groupName

    @currentGroupName   = groupName

    remote.cacheable groupName, (err, models) =>
      if err then callback err
      else if models?
        [group] = models
        if group.bongo_.constructorName isnt 'JGroup'
          @changeGroup 'koding'
        else
          @setGroup groupName
          @currentGroupData.setGroup group
          callback null, groupName, group
          @openGroupChannel getGroup()
          @openSocialGroupChannel getGroup()
          @emit 'ready'

  getUserArea: ->
    @userArea ? { group:
      if globals.config.entryPoint?.type is 'group'
      then globals.config.entryPoint.slug
      else (kd.getSingleton 'groupsController').currentGroupName }

  setUserArea: (userArea) ->
    @userArea = userArea

  getGroupSlug: -> @currentGroupName

  setGroup: (groupName) ->
    @currentGroupName = groupName
    @setUserArea {
      group: groupName, user: whoami().profile.nickname
    }

  joinGroup: (group, callback) ->
    group.join (err, response) ->
      return showError err  if err?
      callback err, response
      kd.getSingleton('mainController').emit 'JoinedGroup'

  acceptInvitation: (group, callback) ->
    whoami().acceptInvitation group, (err, res) =>
      mainController = kd.getSingleton 'mainController'
      mainController.once 'AccountChanged', callback.bind this, err, res
      mainController.accountChanged whoami()

  ignoreInvitation: (group, callback) ->
    whoami().ignoreInvitation group, callback

  cancelGroupRequest: (group, callback) ->
    whoami().cancelRequest group.slug, callback

  cancelMembershipPolicyChange: (policy, membershipPolicyView, modal) ->
    membershipPolicyView.enableInvitations.setValue policy.invitationsEnabled

  updateMembershipPolicy: (group, policy, formData, membershipPolicyView, callback) ->
    group.modifyMembershipPolicy formData, (err) ->
      unless err
        policy.emit 'MembershipPolicyChangeSaved'
        new kd.NotificationView { title: 'Membership policy has been updated.' }
      showError err

  canEditGroup: ->
    ['admin', 'owner'].reduce (prole, role) ->
      prole or (role in globals.userRoles)
    , no

  ###*
   *  Sets given stack template as current group's default stack template
   *  Or sets given stack template as current group's shared stack templates list
   *
   *  @param  {JStackTemplate}  stackTemplate
   *  @param  {String}          type
   *  @param  {Func}            callback  [ err ]
  ###
  setDefaultTemplate: (stackTemplate, type = 'default', callback = kd.noop) ->

    { computeController, reactor }   = kd.singletons
    { slug, stackTemplates, sharedStackTemplates } = currentGroup = @getCurrentGroup()
    { _id: id } = stackTemplate
    if slug is 'koding'
      return callback 'Setting stack template for koding is disabled'

    # Share given stacktemplate with group first
    stackTemplate.setAccess 'group', (err) ->
      return callback err  if err

      if stackTemplates
        unless id in stackTemplates
          stackTemplates.push id
      else
        stackTemplates = [id]
      data = { stackTemplates }

      if type is 'default'
        sharedStackTemplates = [id]
        data = { stackTemplates, sharedStackTemplates }

      currentGroup.modify data, (err) ->
        return callback err  if err

        new kd.NotificationView
          title : "Team (#{slug}) stack has been saved!"
          type  : 'mini'

        reactor.dispatch 'LOAD_TEAM_SUCCESS', { team: currentGroup }

        computeController.createDefaultStack yes
        Tracker.track Tracker.STACKS_MAKE_DEFAULT  if type is 'default'

        if stackTemplate._updated
          id = currentGroup.socialApiDefaultChannelId

        # Warn other group members about stack template update

        if type is 'default'
          currentGroup.sendNotification 'StackTemplateChanged', stackTemplate
        else
          currentGroup.sendNotification 'ShareStackTemplate', stackTemplate

        callback null


  ###*
   *  Remove given stack template from current group's shared stack template list
   *
   *  @param  {JStackTemplate}  stackTemplate
   *  @param  {Func}            callback  [ err ]
  ###
  setPrivate: (stackTemplate, callback = kd.noop) ->

    { computeController, reactor }   = kd.singletons
    { slug, stackTemplates } = currentGroup = @getCurrentGroup()

    if slug is 'koding'
      return callback 'Setting stack template for koding is disabled'

    stackTemplate.setAccess 'private', (err) ->

      return callback err  if err

      if stackTemplates
        index = stackTemplates.indexOf(stackTemplate._id)

        if index > -1
          stackTemplates.splice(index, 1)

      currentGroup.modify { stackTemplates }, (err) ->

        callback err  if err
        reactor.dispatch 'LOAD_TEAM_SUCCESS', { team: currentGroup }
        callback()

        currentGroup.sendNotification 'UnshareStackTemplate', stackTemplate
