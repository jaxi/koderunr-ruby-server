ROUTERS =
  RUN: '/api/run/'
  SAVE: '/api/save/'
  STDIN: '/api/stdin/'
  REGISTER: '/api/register/'
  FETCH: '/api/fetch/'
$ ->
  term = $('#stdio').terminal(undefined,
    name: 'KodeRunr'
    prompt: '> '
    greetings: false)
  editor = ace.edit('editor')
  editor.setTheme 'ace/theme/cobalt'
  editor.setOptions
    fontSize: '10pt'
    tabSize: 2

  KodeRunr = ->
    @term = term
    @term.focus false
    @editor = ace.edit('editor')
    @setLang $('#lang').val()
    @running = false
    return

  KodeRunr::setLang = (lang) ->
    langs = lang.split(' ')
    @lang = langs[0]
    @version = langs[1]
    mode = undefined
    switch @lang
      when 'go'
        mode = 'golang'
      when 'c'
        mode = 'c_cpp'
      else
        mode = @lang
    @editor.getSession().setMode 'ace/mode/' + mode
    return

  KodeRunr::runCode = (evt) ->
    # Do not run code when it's in the middle of running,
    # because it will make the console output messy (and
    # also confusing)
    if @running
      alert 'The code is now running.\n\nYou can either refresh the page or wait for the finishing.'
      return
    # Mark the runner as running.
    @running = true
    sourceCode = @editor.getValue()
    runnable =
      lang: @lang
      source: sourceCode
    if @version
      runnable.version = @version
    runner = this
    $.post ROUTERS.REGISTER, runnable, (uuid) ->
      # Empty the output field
      runner.term.clear()
      runner.term.focus()
      evtSource = new EventSource(ROUTERS.RUN + '?evt=true&uuid=' + uuid)

      evtSource.onmessage = (e) ->
        str = e.data.split('\n').join('')
        if str == ''
          runner.term.echo '\u000d'
        else
          runner.term.echo str
        return

      evtSource.onerror = (e) ->
        if uuid
          uuid = undefined
          runner.term.echo '[[;green;]Completed!]'
          runner.term.focus false
          runner.running = false
        return

      # Get the command and send to stdin.
      runner.term.on 'keydown', (e) ->
        if uuid
          if e.keyCode == 13
            cmd = runner.term.get_command() + '\n'
            $.post ROUTERS.STDIN,
              input: cmd
              uuid: uuid
        return
      return
    return

  KodeRunr::saveCode = (event) ->
    sourceCode = @editor.getValue()
    runnable =
      lang: @lang
      source: sourceCode
    if @version
      runnable.version = @version
    $.post ROUTERS.SAVE, runnable, (codeID) ->
      window.history.pushState codeID, 'KodeRunr#' + codeID, '/#' + codeID
      return
    return

  sourceCodeCache = sourceCodeCache or {}

  sourceCodeCache.fetch = (runner) ->
    localStorage.getItem runner.lang

  sourceCodeCache.store = (runner) ->
    localStorage.setItem runner.lang, runner.editor.getValue()
    return

  runner = new KodeRunr
  codeID = window.location.hash.substring(1)
  if codeID
    $.get ROUTERS.FETCH + '?codeID=' + codeID, (data) ->
      lang = data.lang
      if data.version
        lang = lang + ' ' + data.version
      $('#lang').val lang
      runner.setLang lang
      $('#lang').replaceWith '<span id=\'lang\' class=\'lead\'>' + lang + '</span>'
      runner.editor.setValue data.source, 1
      runner.codeID = codeID
      return
  $('#submitCode').on 'click', (event) ->
    runner.runCode()
    return
  $('#shareCode').on 'click', (event) ->
    runner.saveCode()
    return
  # Shortcuts
  $(document).on 'keydown', (e) ->
    if e.ctrlKey or e.metaKey
      switch e.keyCode
        # run
        when 13
          runner.runCode()
        # save
        when 83
          e.preventDefault()
          runner.saveCode()
    return
  $('#lang').on 'change', ->
    # Empty the screen
    sourceCodeCache.store runner
    runner.editor.setValue '', undefined
    runner.term.clear()
    runner.setLang @value
    cachedSourceCode = sourceCodeCache.fetch(runner)
    if cachedSourceCode
      runner.editor.setValue cachedSourceCode, 1
    return
  return
