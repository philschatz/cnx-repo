#### Dependencies ####
# anything not in the standard library is included in the repo, or
# can be installed with an:
#     npm install

USER_HOST = 'localhost'
USER_PORT = 6543
USER_URL = "http://#{USER_HOST}:#{USER_PORT}"


# Standard lib
fs = require 'fs'
path = require 'path'
http = require 'http'
https = require 'https'
child_process = require 'child_process'
spawn = child_process.spawn

# From npm
mkdirp = require 'mkdirp'
express = require 'express'
_ = require 'lodash'
Sequelize = require 'sequelize'

defargs = require './defaultargs'


# Generate UUIDv4 id's (from http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript)
_uuid = b = (a) ->
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
    app.use(express.cookieParser('secret'))
    app.use(express.bodyParser())
    app.use(express.methodOverride())
    app.use(express.session({ secret: 'notsecret'}))
    app.use(app.router)
    app.use(express.static(argv.c)) if argv.c

  # Show all of the options a server is using.
  log argv

  getUserId = (req)      -> req.signedCookies?.userid?.id
  setUserId = (id, resp) -> resp.cookie('userid', {id:id}, { signed: true })

  # Middleware that loads the UserID from a cookie or assigns one if it does not exist
  authenticated = (req, resp, next) ->
    id = getUserId(req)
    if not id
      id = _uuid()
      setUserId(id, resp)

    # Query or create the User object and squirrel it on the requect
    # So other queries can use it.
    # FIXME: Cache this so we do not have to look up the User on every request
    models.User.findOrCreate({id:id})
    .success (user) ->
      # Save the userId on the request so route handlers can use it
      req.userModel = user
      next()


  app.get '/me', authenticated, authenticated, (req, resp) ->
    resp.send({})

  app.post '/logging', authenticated, (req, resp) ->
    log req.body
    resp.send()

  resolvePromiseError = (promise, resp) ->
    promise.error (err) ->
      log err
      resp.status(400)
      resp.send(err)
    return promise

  resolvePromise = (promise, resp) ->
    resolvePromiseError(promise, resp)
    .success (content) ->
      # If content is an array then there was a QueryChainer and we just need the last item
      content = _.map(content, (o) => o.toJSON()) if _.isArray(content)

      if content
        resp.send(content.toJSON())
      else
        resp.status(404)
        resp.send()

  app.get '/workspace', authenticated, (req, resp) ->
    chainer = new Sequelize.Utils.QueryChainer()
    chainer.add(req.userModel.getContents())
    chainer.add(req.userModel.getFolders())
    promise = chainer.run()
    resolvePromiseError(promise, resp)
    .success (results) ->
      results = _.flatten results
      all = _.map results, (o) -> o.toJSON()
      resp.send(all)


  # Content routes
  # ===============

  app.post ///^/content/?$///, authenticated, (req, resp) ->
    attrs = req.body
    attrs.id = _uuid() # Create a new uuid for the model
    content = models.Content.build(attrs)

    promise = content.save()
    resolvePromiseError(promise, resp)
    .success (content) ->
      # Give the current user permissions to edit the folder
      promise = req.userModel.addContent(content)
      resolvePromiseError(promise, resp)
      .success () ->
        resp.send(content.toJSON())

  app.get ///^/content/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/?$///, authenticated, (req, resp) ->
    id = req.params[0]
    promise = models.Content.find({where: {id:id}})
    resolvePromise(promise, resp)

  app.put ///^/content/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/?///, authenticated, (req, resp) ->
    id = req.params[0]
    attrs = req.body

    # Look up the model before updating so we can return it after the update
    promise = models.Content.find({where: {id:id}})
    resolvePromiseError(promise, resp)
    .success (content) =>
      promise = content.updateAttributes(attrs)
      resolvePromise(promise, resp)

  # Folder routes
  # ===============

  folderHelper = (folder, resp) ->
    promise = folder.getContents()
    resolvePromiseError(promise, resp)
    .success (contents) ->
      json = folder.toJSON()
      json.contents = _.map contents, (o) -> o.toJSON()
      resp.send(json)


  app.post ///^/folder/?$///, authenticated, (req, resp) ->
    attrs = req.body
    attrs.id = _uuid() # Create a new uuid for the model
    folder = models.Folder.build(attrs)

    # Add all the contents by looking them up first
    contentsPromise = models.Content.findAll({where: {id: attrs.contents}})
    resolvePromiseError(contentsPromise, resp)
    .success (contents) ->
      promise = folder.setContents(contents)
      resolvePromiseError(promise, resp)
      .success () ->
        # Give the current user permissions to edit the folder
        promise = req.userModel.addFolder(folder)
        resolvePromiseError(promise, resp)
        .success () ->
          # Finally, return the folder
          folderHelper(folder, resp)

  app.get ///^/folder/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/?$///, authenticated, (req, resp) ->
    id = req.params[0]
    promise = models.Folder.find({where: {id:id}})
    resolvePromiseError(promise, resp)
    .success (folder) =>
      folderHelper(folder, resp)


  app.put ///^/folder/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/?///, authenticated, (req, resp) ->
    id = req.params[0]
    attrs = req.body

    # Look up the model before updating so we can return it after the update
    promise = models.Folder.find({where: {id:id}})
    resolvePromiseError(promise, resp)
    .success (folder) =>
      promise = folder.updateAttributes(attrs)
      resolvePromiseError(promise, resp)
      .success () =>
        # Update the contents by looking them up first
        contentsPromise = models.Content.findAll({where: {id: attrs.contents}})
        resolvePromiseError(contentsPromise, resp)
        .success (contents) ->
          promise = folder.setContents(contents)
          resolvePromiseError(promise, resp)
          .success () ->
            folderHelper(folder, resp)


  # Login and Authentication
  # -------------------------


  remoteVerify = (payload, cb) ->
    options = {
      hostname: USER_HOST
      port: USER_PORT
      method: 'POST'
      path: '/server/check'
    }
    # TODO: This needs more robust error handling, just trying to
    # keep it from taking down the server.
    req = http.request options, (resp) ->
      responsedata = ''
      resp.on 'data', (chunk) ->
        responsedata += chunk

      resp.on 'error', (e) ->
        cb(e, 'Page not found', 404)

      resp.on 'end', ->
        if resp.statusCode == 404
          cb(null, 'Page not found', 404)
        else if responsedata
          cb(null, JSON.parse(responsedata), resp.statusCode)
        else
          cb(null, 'Page not found', 404)

    req.on 'error', (e) ->
      cb(e, 'Page not found', 404)

    req.write(JSON.stringify(payload))


  app.all '/login', authenticated, (req, resp) ->
    cameFrom = req.get('Referrer') or '/'
    userUrl = "#{USER_URL}/server/login?came_from=#{cameFrom}"
    resp.redirect(userUrl)

  app.get '/valid', authenticated, (req, resp) ->
    userToken = req.query['token']
    nextLocation = req.query['next'] or '/'

    # Check with the service to verify authentication is valid.
    remoteVerify {token:userToken}, (err, value) ->
      # if err
      #   resp.status(400)
      #   return resp.send(err)

      # userId = JSON.parse(value).id

      # Now that we have the user's authenticated id, we can associate the user
      #   with the system and any previous session.
      console.log 'FIXME: Do not just use an arbitrary id'
      userId = '00000000-0000-0000-0000-000000000000'


  server = app.listen argv.p, argv.o, ->
    app.emit 'listening'
    loga "Repo server listening on", argv.p, "in mode:", app.settings.env

  # Return app when called, so that it can be watched for events and shutdown with .close() externally.
  app

