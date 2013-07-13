Meteor.methods
  voteUp: (type, id) ->
    userId = Meteor.userId()
    voteFor type, id, userId, 1

  voteDown: (type, id) ->
    userId = Meteor.userId()
    voteFor type, id, userId, -1

voteFor = (type, id, userId, upOrDown) ->
  data = 
    type: "vote"
    userId: userId
    entity: id
    entityType: type
    upOrDown: upOrDown
    date: new Date().getTime()

  vote = Votes.findOne
    userId: userId
    entity: id
  
  if vote
    if false
    else if vote.upOrDown is 1 and upOrDown is 1
      upVotes = -1
      downVotes = 0
      data.upOrDown = 0
    else if vote.upOrDown is 1 and upOrDown is -1
      upVotes = -1
      downVotes = 1
    else if vote.upOrDown is -1 and upOrDown is 1
      upVotes = 1
      downVotes = -1
    else if vote.upOrDown is -1 and upOrDown is -1
      upVotes = 0
      downVotes = -1
      data.upOrDown = 0

    else if vote.upOrDown is 0 and upOrDown is 1
      upVotes = 1
      downVotes = 0
    else if vote.upOrDown is 0 and upOrDown is -1
      upVotes = 0
      downVotes = 1

    Votes.update vote._id, $set: data

  else
    Votes.insert data
    upVotes = if upOrDown is 1 then 1 else 0
    downVotes = if upOrDown is -1 then 1 else 0

  collection = Collections[type]
  calculateScore collection, id, upVotes, downVotes

calculateScore = (collection, id, diffUpVotes, diffDownVotes) ->
  console.log "calulating score..."

  doc = collection.findOne id

  up = doc.upVotes + diffUpVotes
  down = doc.downVotes + diffDownVotes

  naive = naiveScore up, down
  wilson = wilsonScore up, up+down
  hot = hotScore up, down, up+down

  collection.update id,
    $set:
      score: naive
      best: wilson
      hot: hot
    $inc:
      upVotes: diffUpVotes
      downVotes: diffDownVotes


naiveScore = (up, down) ->
  return up - down

# http://amix.dk/blog/post/19588
wilsonScore = (pos, n) ->
  if n <= 0 or pos <= 0
    return 0

  # NOTE: hardcoded for performance (confidence = 0.95)
  z = 1.96
  phat = pos/n

  (phat + z*z/(2*n) - z * Math.sqrt((phat*(1-phat)+z*z/(4*n))/n))/(1+z*z/n)

# http://amix.dk/blog/post/19588
hotScore = (up, down, date) ->
  a = new Date(date).getTime()
  b = new Date(2005, 12, 8, 7, 46, 43).getTime()
  ts = a - b

  x = up - down

  if x > 0 then y = 1
  else if x < 0 then y = -1
  else y = 0

  z = Math.max(Math.abs(x), 1)

  Math.round(Math.log(z)/Math.log(10) + y*ts/45000)
