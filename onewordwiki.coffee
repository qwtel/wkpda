root = exports ? this

root.Things = new Meteor.Collection "things"
root.Properties = new Meteor.Collection "properties"
root.Connections = new Meteor.Collection "connections"

if Meteor.isServer
  Meteor.startup ->
    Meteor.publish "query", (thing, verb) ->
      thingsQ = Things.find
        text: thing
        verb: verb

      thingObject = thingsQ.fetch()[0]
      
      if thingObject
        thingId = thingObject._id
        Things.update thingId, $inc: searchedFor: 1

        connectionsQ = Connections.find thingId: thingId
        connections = connectionsQ.fetch()

        propIds = _.pluck connections, "propertyId"
        propertiesQ = Properties.find _id: $in: propIds
        properties = propertiesQ.fetch()

        console.log _.pluck properties, "text"

        return [thingsQ, connectionsQ, propertiesQ]

      @ready()

if Meteor.isClient
  Meteor.startup ->
    Deps.autorun ->
      thing = Session.get "thing"
      verb = Session.get "verb"

      Meteor.subscribe "query", thing, verb, ->
        thingObject = Things.findOne
          text: thing
          verb: verb
        
        console.log thingObject

        if not thingObject 
          q = thing + " " + verb + " "

          url =  "http://suggestqueries.google.com/complete/search?client=firefox&q="+q
          $.ajax 
            dataType: "jsonp"
            url: url
            success: (data, status) ->
              Meteor.call "update", thing, verb, data, ->
                console.log "updated"
                Meteor.subscribe "query", thing, verb, ->
                  console.log "done"

  Template.form.thing = ->
    Session.get("thing") or ''

  Template.form.verb = (verb) ->
    if Session.get("verb") is verb then "selected" else ''

  Template.form.events
    'click button': (e) ->
      thing = $('#thing').val()
      verb = $('#verb').val()
      Session.set "thing", thing
      Session.set "verb", verb

  Template.properties.properties = ->
    thing = Session.get "thing"
    verb = Session.get "verb"

    thingObject = Things.findOne 
      text: thing
      verb: verb

    if thingObject
      connections = Connections.find thingId: thingObject._id
      connections = connections.fetch()

      propertyIds = _.pluck connections, "propertyId"
      Properties.find _id: $in: propertyIds

  Template.property.q = ->
    thing = Session.get "thing"
    verb = Session.get "verb"
    thing + " " + verb + " " + @text

  Template.property.gt0 = ->
    @thingsCount > 1

  Template.property.thingsCount = ->
    @thingsCount - 1

  #Template.body.events
  #  'click a[href^="/"]': (e) ->
  #    if e.which is 1 and not (e.ctrlKey or e.metaKey)
  #      e.preventDefault()
  #      $t = $(e.target).closest 'a[href^="/"]'
  #      href = $t.attr "href"
  #      if href then Router.navigate href, true

if Meteor.isServer
  Meteor.methods
    update: (thing, verb, data) ->
      console.log data[0], data[1]

      date = new Date().getTime()
      thingId = Things.insert 
        text: thing
        verb: verb
        date: date
        searchedFor: 1

      replace = (p, thing) ->
        re = new RegExp thing+"\\s" 
        p = p.replace re, ''

      properties = data[1]
      for p in properties
        p = replace p, thing
        p = replace p, verb
        console.log p

        propertyObject = Properties.findOne text: p
        if propertyObject
          propertyId = propertyObject._id

          Properties.update propertyId, 
            $inc: 
              thingsCount: 1

          console.log "WHAT THE FUCK??"
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
