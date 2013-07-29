#### Dependencies ####
# anything not in the standard library is included in the repo, or
# can be installed with an:
#     npm install

REPO_URL = 'http://localhost:3000'

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

  # Show all of the options a server is using.
  log argv

  app.all '/server/check', (req, resp) ->
    token = req.body.token
    resp.send {id:token}


  # Login and Authentication
  # -------------------------

  app.all '/server/login', (req, resp) ->
    cameFrom = req.query.came_from
    resp.redirect("#{REPO_URL}/valid?token=#{_uuid()}&next=#{cameFrom}")

  server = app.listen argv.p, argv.o, ->
    app.emit 'listening'
    loga "Repo server listening on", argv.p, "in mode:", app.settings.env

  # Return app when called, so that it can be watched for events and shutdown with .close() externally.
  app

