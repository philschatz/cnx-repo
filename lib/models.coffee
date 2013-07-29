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
    #contents: Sequelize.ARRAY(Sequelize.TEXT)

  User = sequelize.define 'User',
    id: Sequelize.STRING


  Content.hasMany(User, {as: 'Editors'})
  Folder.hasMany(User, {as: 'Editors'})
  User.hasMany(Content)
  User.hasMany(Folder)

  Folder.hasMany(Content)
  Content.hasMany(Folder) # Just to make sure Content to Folder is a many-to-many



  if argv.dbinit
    console.log "Creating tables if needed. db='#{argv.db}' with user='#{argv.dbu}'"
    Content.sync()
    Folder.sync()
    User.sync()


    # The many-to-many relation tables by default use an INTEGER for their identifier.
    # Since we use a uuid string, change the table structure
    ContentsFolders = sequelize.define 'ContentsFolders',
      ContentId: {type:Sequelize.STRING, primaryKey:true}
      FolderId: {type:Sequelize.STRING, primaryKey:true}

    ContentsUsers = sequelize.define 'ContentsUsers',
      ContentId: {type:Sequelize.STRING, primaryKey:true}
      UserId: {type:Sequelize.STRING, primaryKey:true}

    FoldersUsers = sequelize.define 'FoldersUsers',
      FolderId: {type:Sequelize.STRING, primaryKey:true}
      UserId: {type:Sequelize.STRING, primaryKey:true}

    ContentsFolders.sync({force:true})
    ContentsUsers.sync({force:true})
    FoldersUsers.sync({force:true})


  return {
    Content: Content
    Folder: Folder
    User: User
  }
