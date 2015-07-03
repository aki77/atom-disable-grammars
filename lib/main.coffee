_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'

module.exports = AtomDisableGrammars =
  subscriptions: null

  config:
    packages:
      type: 'array'
      default: []
      items:
        type: 'string'

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @removedGrammars = new Set
    @debug = atom.inDevMode() and not atom.inSpecMode()

    @debouncedReload = _.debounce((=> @reload()), 1000)
    @subscriptions.add(atom.config.onDidChange('disable-grammars.packages', @debouncedReload))

    @subscriptions.add(atom.packages.onDidActivateInitialPackages( => @init()))

    @subscriptions.add(atom.commands.add('atom-workspace', 'disable-grammars:reload', =>
      @reload()
    ))

  deactivate: ->
    @subscriptions?.dispose()
    @subscriptions = null
    @reset()

  init: ->
    @reload()
    @subscriptions.add(atom.packages.onDidLoadPackage((pack) => @onLoadedPackage(pack)))

  # need update-package
  onLoadedPackage: (pack) ->
    return @debouncedReload() if pack.settingsActivated

    activateResources = pack.activateResources
    pack.activateResources = =>
      activateResources.call(pack)
      pack.activateResources = activateResources
      console.log 'activateResources', pack if @debug
      @debouncedReload()

  reload: ->
    @reset()
    oldGrammars = atom.grammars.getGrammars()

    for name in atom.config.get('disable-grammars.packages')
      pack = atom.packages.getLoadedPackage(name)
      continue unless pack
      for grammar in pack.grammars
        atom.grammars.removeGrammar(grammar)

        sameScopeGrammar = _.find(atom.grammars.getGrammars(), ({scopeName}) ->
          scopeName is grammar.scopeName
        )

        # reset grammarsByScopeName
        if sameScopeGrammar
          atom.grammars.removeGrammar(sameScopeGrammar)
          atom.grammars.addGrammar(sameScopeGrammar)

    for binding in _.difference(oldGrammars, atom.grammars.getGrammars())
      console.log 'disable grammar', grammar if @debug
      @removedGrammars.add(grammar)
    return

  reset: ->
    grammars = atom.grammars.getGrammars()
    @removedGrammars.forEach((grammar) ->
      if grammar not in grammars
        console.log 'enable grammar', grammar if @debug
        atom.grammars.addGrammar(grammar)
    )
    @removedGrammars.clear()
