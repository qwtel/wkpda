root = exports ? this

root.Things = new Meteor.Collection "things"
root.Properties = new Meteor.Collection "properties"
root.Connections = new Meteor.Collection "connections"
root.Votes = new Meteor.Collection "votes"

root.Collections =
  'thing': Things
  'property': Properties
  'connection': Connections
  'vote': Votes

class Router extends Backbone.Router
  routes:
    "": "home"
    "thing/:id": "thing"
    "property/:id": "property"

  home: ->
    Session.set "page", null
    Session.set "thingId", null
    Session.set "propertyId", null

  thing: (id) ->
    Session.set "page", "thing"
    Session.set "thingId", id

  property: (id) ->
    Session.set "page", "property"
    Session.set "propertyId", id

Router = new Router

if Meteor.isServer
  Meteor.startup ->
    migrate = (collection, name) ->
      collection.update {},
        $set:
          type: name
          #upVotes: 0
          #downVotes: 0
          #score: 0
          #hot: 0
          #best: 0
      ,
        multi: true

    migrate Things, 'thing'
    migrate Properties, 'property'
    migrate Connections, 'connection'

    Meteor.publish "popular", ->
      Things.find {},
        sort: searchedFor: -1
        limit: 10

    Meteor.publish "property", (propertyId) ->
      propertyQ = Properties.find propertyId

      connectionsQ = Connections.find propertyId: propertyId
      connections = connectionsQ.fetch()

      thingIds = _.pluck connections, "thingId"
      thingsQ = Things.find _id: $in: thingIds

      [propertyQ, thingsQ, connectionsQ]

    Meteor.publish "thing", (thingId) ->
      thingQ = Things.find thingId
      thingObject = thingQ.fetch()[0]
      
      if thingObject
        thingId = thingObject._id
        Things.update thingId, $inc: searchedFor: 1

        connectionsQ = Connections.find thingId: thingId
        connections = connectionsQ.fetch()

        propIds = _.pluck connections, "propertyId"
        propertiesQ = Properties.find _id: $in: propIds
        properties = propertiesQ.fetch()

        #console.log _.pluck properties, "text"

        [thingQ, connectionsQ, propertiesQ]

if Meteor.isClient
  Handlebars.registerHelper "equals", (name, value) ->
    Session.equals name, value

  Handlebars.registerHelper "percentage", ->
    Math.round @best * 100

  Meteor.startup ->
    Backbone.history.start pushState: true

    # make Meteor.userId() work for this browser session
    if not Meteor.userId()?
      Meteor.loginAnonymously()

    Meteor.subscribe "popular"

    Deps.autorun ->
      page = Session.get "page"
      if page is "property"
        propertyId = Session.get "propertyId"
        if propertyId
          Meteor.subscribe "property", propertyId

      else if page is "thing"
        thingId = Session.get "thingId"
        if thingId
          Meteor.subscribe "thing", thingId, ->
            # this would be too much refactoring, just hack
            thingObject = Things.findOne thingId
            Session.set "thing", thingObject.text
            Session.set "verb", thingObject.verb

  Template.popular.things = ->
    handle = Things.find {},
      sort: searchedFor: -1
      limit: 10

    things = []
    handle.forEach (thing) ->
      thing.noVote = true
      console.log thing
      things.push thing
    things

  Template.form.thing = ->
    Session.get("thing") or ''

  Template.form.verb = (verb) ->
    if Session.get("verb") is verb then "selected" else ''

  Template.form.events
    'click button': (e) ->
      thing = $('#thing').val().toLowerCase()
      verb = $('#verb').val().toLowerCase()

      Meteor.call "getThingId", thing, verb, (err, res) ->
        if not err
          if not res is false
            Router.navigate "/thing/"+res, true

          else
            q = thing + " " + verb + " "


            #searchProviders = [
            #  "http://suggestqueries.google.com/complete/search?client=firefox&q=",
            #  "http://ff.search.yahoo.com/gossip?output=fxjson&command=",
            #  "http://api.bing.com/osjson.aspx?query="
            #]

            #choice = Random.choice searchProviders
            #url = choice + q

            url = "http://suggestqueries.google.com/complete/search?client=firefox&q=" + q

            $.ajax 
              dataType: "jsonp"
              url: url
              success: (data, status) ->
                Meteor.call "update", thing, verb, data, (err, res) ->
                  if not err
                    Router.navigate "/thing/"+res, true
                    Meteor.flush()

                    Meteor.call "assignImages", res

  Template.things.property = -> 
    id = Session.get "propertyId"
    Properties.findOne(id)?.text

  Template.properties.thing = -> Session.get "thing"

  Template.properties.thingObject = -> 
    thing = Session.get "thing"
    Things.findOne text: thing

  Template.things.propertyObject = -> 
    id = Session.get "propertyId"
    Properties.findOne id

  Template.properties.verb = -> Session.get "verb"

  copyScore = (context, obj) ->
    if obj
      obj.score = context.score
      obj.hot = context.hot
      obj.best = context.best
    obj

  Template.properties.property = -> 
    obj = Properties.findOne @propertyId
    copyScore this, obj

  Template.properties.connections = ->
    thingId = Session.get "thingId"
    if thingId
      connections = Connections.find thingId: thingId,
        sort: best: -1

  Template.things.thing = -> 
    obj = Things.findOne @thingId
    copyScore this, obj

  Template.things.connections = ->
    propertyId = Session.get "propertyId"
    if propertyId
      connections = Connections.find propertyId: propertyId,
        sort: best: -1

  Template.property.q = ->
    thing = Session.get "thing"
    verb = Session.get "verb"
    thing + " " + verb + " " + @text

  Template.property.image = ->
    @images?[1] or '/img/bg_new.png'

  Template.thing.image = ->
    @images?[1] or '/img/bg_new.png'

  Template.property.events
    "click .other-things": (e) ->
      Session.set "propertyId", @_id
      Session.set "page", "property"

  Template.property.gt0 = ->
    @thingsCount > 1

  Template.property.thingsCount = ->
    @thingsCount - 1

  Template.property.rendered = ->
    $(@find('a[title]')).tooltip
      placement: 'right'

  Template.vote.events
    "click .vote-up": (e) ->
      thingId = if Session.equals('page', 'thing') then Session.get('thingId') else @_id
      propertyId = if Session.equals('page', 'property') then Session.get('propertyId') else @_id

      console.log thingId, propertyId

      con = Connections.findOne 
        thingId: thingId
        propertyId: propertyId
      
      console.log con

      Meteor.call 'voteUp', con.type, con._id
      #Meteor.call 'voteUp', 'thing', thingId

    "click .vote-down": (e) ->
      thingId = if Session.equals('page', 'thing') then Session.get('thingId') else @_id
      propertyId = if Session.equals('page', 'property') then Session.get('propertyId') else @_id

      con = Connections.findOne 
        thingId: thingId
        propertyId: propertyId

      Meteor.call 'voteDown', con.type, con._id
      #Meteor.call 'voteDown', 'thing', thingId

  Template.body.events
    'click a[href^="/"]': (e) ->
      if e.which is 1 and not (e.ctrlKey or e.metaKey)
        e.preventDefault()
        $t = $(e.target).closest 'a[href^="/"]'
        href = $t.attr "href"
        if href then Router.navigate href, true

if Meteor.isServer
  Meteor.methods
    reset: ->
      Votes.remove({})
      #Things.remove({})
      #Connections.remove({})
      #Properties.remove({})

    getThingId: (thing, verb) ->
      thingObject = Things.findOne
        text: thing
        verb: verb
      
      if thingObject then thingObject._id else false

    update: (thing, verb, data) ->
      #fail = 0
      properties = data[1]
      ps = []
      for p in properties
        re = new RegExp "^"+thing+"\\s" 

        #if not re.test p
        #  fail++
        #  if fail > properties.length/2
        #    throw new Meteor.Error p

        # remove the thing from the string, but only when it is at the beginning
        p = p.replace re, ' '

        # remove the verb from the string, but only when it is at the beginning
        re = new RegExp "^"+"\\s"+verb+"\\s" 
        p = p.replace re, ' '

        # dealing with white space
        p = p.replace /\s{2,}/g, ' '
        p = p.replace /^\s+|\s+$/g, ''

        ps.push p

      date = new Date().getTime()
      thingId = Things.insert 
        text: thing
        verb: verb
        date: date
        searchedFor: 1

      for p in ps
        propertyObject = Properties.findOne text: p
        if propertyObject
          propertyId = propertyObject._id

          Properties.update propertyId, 
            $inc: 
              thingsCount: 1

        else
          propertyId = Properties.insert 
            text: p
            date: date
            thingsCount: 1

        Connections.insert
          thingId: thingId
          propertyId: propertyId
          date: date
          upVotes: 0
          downVotes: 0
          voters: []
          score: 0
          hot: 0
          best: 0

      return thingId

    assignImages: (thingId) ->
      thingObject = Things.findOne(thingId)
      if thingObject and not thingObject.images
        thing = thingObject.text
        assignImage thing, Things, thingId

        connectionsQ = Connections.find thingId: thingId
        connections = connectionsQ.fetch()
        propertyIds = _.pluck connections, "propertyId"

        for propertyId in propertyIds
          propertyObject = Properties.findOne(propertyId)
          if propertyObject and not propertyObject.images and propertyObject.thingsCount > 1
            property = propertyObject.text
            assignImage property, Properties, propertyId

assignImage = (q, collection, entityId) ->

  #rootUri = 'https://api.datamarket.azure.com/Bing/Search/v1/Composite'
  rootUri = 'https://api.datamarket.azure.com/Bing/Search/Image'

  # Get the query. Default to 'sushi'.
  query = if q then "'#{q}'" else "'sushi'"

  # Get the service operation.
  serviceOp = "'image'"

  # Get the market. Default to en-us.
  market = "'en-us'"

  # Encode the credentials and create the stream context.
  auth = new Buffer(ACC_KEY+":"+ACC_KEY).toString 'base64'

  res = Meteor.http.get rootUri,
    headers:
      'Authorization': "Basic #{auth}"
    params:
      'Query': query
      'Market': market
      '$top': 5
      '$format': 'json'
      #'Sources': serviceOp

  if res? and res.data? and res.data.d? and res.data.d.results?
    thumbnails = []
    for image in res.data.d.results
      if image['Thumbnail']
        thumbnails.push image['Thumbnail']

    mediaUrls = _.pluck thumbnails, "MediaUrl"

    if collection? and entityId?
      collection.update entityId,
        $set:
          images: mediaUrls

  return res
