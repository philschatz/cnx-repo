Sequelize = require 'sequelize'

module.exports = (argv) ->
  sequelize = new Sequelize argv.db, argv.dbu, argv.dbp,
    # gimme postgres, please!
    dialect: 'postgres'

  Content = sequelize.define 'Content',
    id: Sequelize.STRING
    mediaType: Sequelize.STRING
    title: Sequelize.STRING
    body: Sequelize.TEXT

  Folder = sequelize.define 'Folder',
    id: Sequelize.STRING
    mediaType: Sequelize.STRING
    title: Sequelize.STRING
    contents: Sequelize.ARRAY(Sequelize.TEXT)

  User = sequelize.define 'User',
    id: Sequelize.STRING

  User.hasMany(Content)
  User.hasMany(Folder)
  Content.hasMany(User, {as: 'Editors'})
  Folder.hasMany(User, {as: 'Editors'})

  if argv.dbinit
    console.log "Creating tables if needed. db='#{argv.db}' with user='#{argv.dbu}'"
    Content.sync()
    Folder.sync()
    User.sync()

  return {
    Content: Content
    Folder: Folder
    User: User
  }
