###
# traverse
traverse = (node, onNode, parents = []) !->
  | not node   => return
  | not onNode => return
  | otherwise
    onNode node, parents
    namelist = if node.name then [node.name] else []
    for child in (node.children or [])
      traverse child, onNode, parents.concat namelist
###
# transform
##
# onNode should return a new object here.
transform = (node, onNode, parents = []) ->
  | not node   => return
  | otherwise
    new-node = if onNode
      then onNode node, parents
      else {}
    namelist = if node.name then [node.name] else []
    new-node.children = for child in (node.children or [])
      transform child, onNode, parents.concat namelist
    new-node

module.exports = {
  traverse
  transform
}
