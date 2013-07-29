# **cli.coffee** command line interface for the express server

optimist = require 'optimist'
server = require './user-mock-server'
cc = require 'config-chain'

# Handle command line options

argv = optimist
  .usage('Usage: $0')
  .options('p',
    alias     : 'port'
    describe  : 'Port'
  )
  .options('r',
    alias     : 'root'
    describe  : 'Application root folder'
  )
  .options('h',
    alias     : 'help'
    boolean   : true
    describe  : 'Show this help info and exit'
  )
  .options('config',
    alias     : 'conf'
    describe  : 'Optional config file.'
  )
  .argv

config = cc(argv,
  argv.config,
).store

# If h/help is set print the generated help message and exit.
if argv.h
  optimist.showHelp()
else
  server(config)

