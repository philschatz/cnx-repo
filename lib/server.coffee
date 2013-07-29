#### Dependencies ####
# anything not in the standard library is included in the repo, or
# can be installed with an:
#     npm install

# Standard lib
fs = require 'fs'
path = require 'path'
http = require 'http'
child_process = require 'child_process'
spawn = child_process.spawn

# From npm
mkdirp = require 'mkdirp'
express = require 'express'
_ = require 'lodash'
Sequelize = require 'sequelize'

defargs = require './defaultargs'


# Generate UUIDv4 id's (from http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript)
uuid = b = (a) ->
  (if a then (a ^ Math.random() * 16 >> a / 4).toString(16) else ([1e7] + -1e3 + -4e3 + -8e3 + -1e11).replace(/[018]/g, b))

# Set export objects for node and coffee to a function that generates a sfw server.
module.exports = exports = (argv) ->
  # Create the main application object, app.
  app = express()

  # defaultargs.coffee exports a function that takes the argv object
  # that is passed in and then does its
  # best to supply sane defaults for any arguments that are missing.
  argv = defargs(argv)

  models = require('./models')(argv)

  app.startOpts = do ->
    options = {}
    for own k, v of argv
      options[k] = v
    options

  log = (stuff...) ->
    console.log stuff if argv.debug

  loga = (stuff...) ->
    console.log stuff

  #### Express configuration ####
  # Set up all the standard express server options,
  # including hbs to use handlebars/mustache templates
  # saved with a .html extension, and no layout.
  app.configure ->
    app.use(express.cookieParser())
    app.use(express.bodyParser())
    app.use(express.methodOverride())
    app.use(express.session({ secret: 'notsecret'}))
    app.use(app.router)
    app.use(express.static(argv.c)) if argv.c

  # Show all of the options a server is using.
  log argv


  app.get '/me', (req, resp) ->
    resp.send({})

  app.get '/workspace', (req, resp) ->
    # TODO: Look up the user
    resp.send([])

  app.post '/logging', (req, resp) ->
    log req.body
    resp.send()

  VALID_ATTRS = [
    'mediaType'
    'title'
    'body'
  ]

  resolvePromise = (promise, resp) ->
    promise.error (err) ->
      log err
      resp.status(400)

    promise.success (content) ->
      # If content is an array then there was a QueryChainer and we just need the last item
      content = _.last(content) if _.isArray(content)

      if content
        resp.send(content.toJSON())
      else
        resp.status(404)

  app.post ///^/content/?$///, (req, resp) ->
    id = uuid() # Create a new uuid for the model
    attrs = req.body
    attrs = _.pick attrs, VALID_ATTRS
    attrs.id = id
    content = models.Content.build(attrs)

    promise = content.save()
    resolvePromise(promise, resp)

  app.get ///^/content/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/?$///, (req, resp) ->
    id = req.params[0]
    promise = models.Content.find({where: {id:id}})
    resolvePromise(promise, resp)

  app.put ///^/content/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$/?///, (req, resp) ->
    id = req.params[0]
    attrs = req.body
    attrs = _.pick attrs, VALID_ATTRS

    # Look up the model before updating so we can return it after the update
    models.Content.find({where: {id:id}})
    .error( (err) =>
      log err
      resp.status(404)
    )
    .success (content) =>
      promise = content.updateAttributes(attrs)
      resolvePromise(promise, resp)


  server = app.listen argv.p, argv.o, ->
    app.emit 'listening'
    loga "Repo server listening on", argv.p, "in mode:", app.settings.env

  # Return app when called, so that it can be watched for events and shutdown with .close() externally.
  app

