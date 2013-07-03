class CollaborativeEditorPane extends CollaborativePane

  constructor: (options = {}, data) ->

    super options, data

    log "i am a CollaborativeEditorPane and my session key is #{options.sessionKey}"

    @container = new KDView

    @container.on "viewAppended", =>
      @codeMirrorEditor = CodeMirror @container.getDomElement()[0],
        lineNumbers     : yes
        mode            : "javascript"
        extraKeys       :
          "Cmd-S"       : @bound "save"

      @panel      = @getDelegate()
      @workspace  = @panel.getDelegate()
      @sessionKey = @getOptions().sessionKey or @createSessionKey()
      @ref        = @workspace.firepadRef.child @sessionKey
      @firepad    = Firepad.fromCodeMirror @ref, @codeMirrorEditor

      @firepad.on "ready", =>
        {file, content} = @getOptions()
        return @openFile file, content  if file
        if @firepad.isHistoryEmpty()
          @firepad.setText "" # fix for a firepad bug

      @ref.on "value", (snapshot) =>
        return @save()  if snapshot.val().WaitingSaveRequest is yes

  openFile: (file, content) ->
    @setData    file
    @setContent content

  setContent: (content) ->
    @firepad.setText content

  save: ->
    file        = @getData()
    amIHost     = @panel.amIHost @sessionKey
    isValidFile = file instanceof FSFile

    if amIHost
      return warn "no file instance handle save as" unless isValidFile

      log "host is saving a file"
      @ref.child("WaitingSaveRequest").set no
      file.save @firepad.getText(), (err, res) =>
        new KDNotificationView
          type     : "mini"
          cssClass : "success"
          title    : "File has been saved"
          duration : 4000
    else
      log "client wants to save a file"
      @ref.child("WaitingSaveRequest").set yes

  pistachio: ->
    """
      {{> @header}}
      {{> @container}}
    """