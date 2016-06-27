/*
 SKTilemap
 SKTilemapLayer.swift
 
 Created by Thomas Linthwaite on 07/04/2016.
 GitHub: https://github.com/TomLinthwaite/SKTilemap
 Website (Guide): http://tomlinthwaite.com/
 Wiki: https://github.com/TomLinthwaite/SKTilemap/wiki
 YouTube: https://www.youtube.com/channel/UCAlJgYx9-Ub_dKD48wz6vMw
 Twitter: https://twitter.com/Mr_Tomoso
 
 -----------------------------------------------------------------------------------------------------------------------
 MIT License
 
 Copyright (c) 2016 Tom Linthwaite
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 -----------------------------------------------------------------------------------------------------------------------
 */

import SpriteKit

// MARK: SKTileLayer
class SKTilemapLayer : SKNode {
    
// MARK: Properties
    override var hashValue: Int { get { return name!.hashValue } }
    
    /** Properties shared by all TMX object types. */
    var properties: [String : String] = [:]
    
    /** The offset to draw this layer at from the tilemap position. */
    let offset: CGPoint
    
    /** The tilemap this layer has been added to. */
    let tilemap: SKTilemap
    
    /** A 2D array representing the tile layer data. */
    private var tiles: [[SKTilemapTile?]]
    
    /** The size of the layer in tiles. */
    private var size: CGSize { get { return tilemap.size } }
    private var sizeHalved: CGSize { get { return CGSize(width: size.width / 2, height: size.height / 2) } }
    
    /** The tilemap tile size. */
    private var tileSize: CGSize { get { return tilemap.tileSize } }
    private var tileSizeHalved: CGSize { get { return CGSize(width: tileSize.width / 2, height: tileSize.height / 2) } }
    
    /** Used when clipping tiles outside of a set bounds. See: 'func clipTilesOutOfBounds()'*/
    private var previouslyShownTiles: [SKTilemapTile] = []
    
// MARK: Initialization
    
    /** Initialize an empty tilemap layer */
    init(tilemap: SKTilemap, name: String, offset: CGPoint = CGPoint.zero) {
        
        self.tilemap = tilemap
        self.offset = offset
        
        tiles = Array(repeating: Array(repeating: nil, count: Int(tilemap.size.width)), count: Int(tilemap.size.height))
        
        super.init()
        
        self.name = name
    }
    
    /** Initialize a tile layer from tmx parser attributes. Should probably only be called by SKTilemapParser. */
    init?(tilemap: SKTilemap, tmxParserAttributes attributes: [String : String]) {
        
        guard
            let name = attributes["name"]
            else {
                print("SKTilemapLayer: Failed to initialize with tmxAttributes.")
                return nil
        }
        
        if
            let offsetX = attributes["offsetx"] where (Int(offsetX) != nil),
            let offsetY = attributes["offsety"] where (Int(offsetY) != nil) {
            offset = CGPoint(x: Int(offsetX)!, y: Int(offsetY)!)
        } else {
            offset = CGPoint.zero
        }
        
        self.tilemap = tilemap
        tiles = Array(repeating: Array(repeating: nil, count: Int(tilemap.size.width)), count: Int(tilemap.size.height))
        
        super.init()
        
        self.name = name
        
        if let opacity = attributes["opacity"] where (Double(opacity)) != nil {
            alpha = CGFloat(Double(opacity)!)
        }
        
        if let visible = attributes["visible"] where (Int(visible)) != nil {
            isHidden = (Int(visible)! == 0 ? true : false)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
// MARK: Debug
    func printDebugDescription() {
        print("\nSKTileLayer: \(name), Offset: \(offset), Opacity: \(alpha), Visible: \(!isHidden)")
        print("Properties: \(properties)")
    }
    
// MARK: Tiles
    
    /** Initialize the layer with in for the form of a 1 dimensional Int array. The array represents each a tile GID for
        its respective location on the map. */
    func initializeTilesWithData(data: [Int]) -> Bool {
        
        if data.count != Int(size.width) * Int(size.height) {
            print("SKTilemapLayer: Failed to initialize tile data. Data size is invalid.")
            return false
        }
        
        //removeAllTiles()
        
        for i in 0..<data.count {
            
            let gid = data[i]
            
            if gid == 0 { continue }
            
            let x = i % Int(size.width)
            let y = i / Int(size.width)
            let tile = setTileAtCoord(x: x, y, id: gid).tileSet
            tile?.playAnimation(tilemap: tilemap)
        }
        
        return true
    }
    
    /** Initialize the layer with a single tile GID. (All tiles will be set to this GID. */
    func initializeTilesWithID(id: Int) {
        
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                setTileAtCoord(x: x, y, id: id)
            }
        }
    }
    
    /** Returns true if the x/y position passed into the function relates to a valid coordinate on the map. */
    func isValidCoord(x: Int, y: Int) -> Bool {
        return x >= 0 && x < Int(size.width) && y >= 0 && y < Int(size.height)
    }
    
    /** Remove a particular tile at a map position. Will return the tile that was removed or nil if the tile did not exist or
     the location was invalid.  */
    func removeTileAtCoord(x: Int, _ y: Int) -> SKTilemapTile? {
        return setTileAtCoord(x: x, y, tile: nil).tileRemoved
    }
    
    func removeTileAtCoord(coord: CGPoint) -> SKTilemapTile? {
        return setTileAtCoord(x: Int(coord.x), Int(coord.y), tile: nil).tileRemoved
    }
    
    /** Removes all tiles from the layer. */
    func removeAllTiles() {
        
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                removeTileAtCoord(x: x, y)
            }
        }
    }
    
    /** Returns a tile at a given map coord or nil if no tile exists or the position was outside of the map. */
    func tileAtCoord(x: Int, _ y: Int) -> SKTilemapTile? {
        
        if !isValidCoord(x: x, y: y) {
            return nil
        }
        
        return tiles[y][x]
    }
    
    /** Returns a tile at a given map coord or nil if no tile exists or the position was outside of the map. */
    func tileAtCoord(coord: CGPoint) -> SKTilemapTile? {
        return tileAtCoord(x: Int(coord.x), Int(coord.y))
    }
    
    /** Returns the tile at a certain position within the layer. */
    func tileAtPosition(positionInLayer: CGPoint) -> SKTilemapTile? {
        if let coord = coordAtPosition(positionInLayer: positionInLayer, round: true) {
            return tileAtCoord(x: Int(coord.x), Int(coord.y))
        }
        return nil
    }
    
    #if os(iOS)
    /* Returns a tile at a given touch position. A custom offset can also be used. */
    func tileAtTouchPosition(touch: UITouch, offset: CGPoint = CGPoint.zero) -> SKTilemapTile? {
        
        if let coord = coordAtTouchPosition(touch: touch, offset: offset, round: true) {
            return tileAtCoord(coord: coord)
        }
        
        return nil
    }
    #endif
    
    #if os(OSX)
    func tileAtMousePosition(event: NSEvent, offset: CGPoint = CGPointZero) -> SKTilemapTile? {
        
        if let coord = coordAtMousePosition(event, offset: offset, round: true) {
            return tileAtCoord(coord)
        }
        
        return nil
    }
    #endif
    
    /* Returns a tile at a given screen position. A custom offet can be used. */
    func tileAtScreenPosition(position: CGPoint, offset: CGPoint = CGPoint.zero) -> SKTilemapTile? {
        
        if let coord = coordAtScreenPosition(position: position, offset: offset, round: true, mustBeValid: true) {
            return tileAtCoord(coord: coord)
        }
        
        return nil
    }
    
    /** Set a specific position on the map to represent the given tile. Nil can also be passed to
        remove a tile at this position (although removeTile(x:y:) is the prefered method for doing this).
        Will return a tuple containing the tile that was removed and the tile that was set. They can be nil
        if neither is true. */
    func setTileAtCoord(x: Int, _ y: Int, tile: SKTilemapTile?) -> (tileSet: SKTilemapTile?, tileRemoved: SKTilemapTile?) {
        
        if !isValidCoord(x: x, y: y) {
            return (nil, nil)
        }
        
        var tileRemoved: SKTilemapTile?
        
        if let tile = tileAtCoord(x: x, y) {
            tile.removeFromParent()
            tileRemoved = tile
        }
        
        tiles[y][x] = tile
        
        if let setTile = tile {
            
            addChild(setTile)
            setTile.position = tilePositionAtCoord(x: x, y, offset: setTile.tileData.tileset.tileOffset)
            setTile.anchorPoint = tilemap.orientation.tileAnchorPoint()
        }
        
        return (tile, tileRemoved)
    }
    
    func setTileAtCoord(coord: CGPoint, tile: SKTilemapTile?) -> (tileSet: SKTilemapTile?, tileRemoved: SKTilemapTile?) {
        
        return setTileAtCoord(x: Int(coord.x), Int(coord.y), tile: tile)
    }
    
    /** Set a specific position on the map to represent the given tile by ID.
        Will return a tuple containing the tile that was removed and the tile that was set. They can be nil
        if neither is true. */
    func setTileAtCoord(x: Int, _ y: Int, id: Int) -> (tileSet: SKTilemapTile?, tileRemoved: SKTilemapTile?) {
        
        if let tileData = tilemap.getTileData(id: id) {
            return setTileAtCoord(x: x, y, tile: SKTilemapTile(tileData: tileData, layer: self))

        }
        
        return (nil, nil)
    }
    
    func setTileAtCoord(coord: CGPoint, id: Int) -> (tileSet: SKTilemapTile?, tileRemoved: SKTilemapTile?) {
        return setTileAtCoord(x: Int(coord.x), Int(coord.y), id: id)
    }
    
// MARK: Tile Coordinates & Positioning
    
    /** Returns the position a tile should be within the layer if they have a certain map position. */
    func tilePositionAtCoord(x: Int, _ y: Int, offset: CGPoint = CGPoint.zero) -> CGPoint {
        
        let tileAnchorPoint = tilemap.orientation.tileAnchorPoint()
        var position = CGPoint.zero
        
        switch tilemap.orientation {
            
        case .Orthogonal:
            position = CGPoint(x: x * Int(tileSize.width) + Int(tileAnchorPoint.x * tileSize.width),
                               y: y * Int(-tileSize.height) - Int(tileSize.height - tileAnchorPoint.y * tileSize.height))
            
        case .Isometric:
            position = CGPoint(x: (x - y) * Int(tileSizeHalved.width) - Int(tileSizeHalved.width - tileAnchorPoint.x * tileSize.width),
                               y: (x + y) * Int(-tileSizeHalved.height) - Int(tileSize.height - tileAnchorPoint.y * tileSize.height))
            
        }
        
        /* Re-position tile based on the tileset offset. */
        position.x = position.x + (offset.x - tileAnchorPoint.x * offset.x)
        position.y = position.y - (offset.y - tileAnchorPoint.y * offset.y)
        
        return position
    }
    
    /** Returns the coordinate from a specific position within the layer. 
        If the position gets converted to a coordinate that is not valid nil is returned.  Otherwise the tile coordinate
        is returned.
        A custom offset point can be passed to this function which is useful if the tileset being used has an offset.
        Passing the round parameter as true will return a whole number coordinate (the default), or a decimal number
        which can be used to determine where exactly within the tile the layer position is. */
    func coordAtPosition(positionInLayer: CGPoint, offset: CGPoint = CGPoint.zero, round: Bool = true, mustBeValid: Bool = true) -> CGPoint? {
        
        var coord = CGPoint.zero
        
        let tileAnchorPoint = tilemap.orientation.tileAnchorPoint()
        let position = CGPoint(x: positionInLayer.x - (self.offset.x * tileAnchorPoint.x) + (offset.x - tileAnchorPoint.x * offset.x),
                               y: positionInLayer.y + (self.offset.y * tileAnchorPoint.y) - (offset.y - tileAnchorPoint.y * offset.y))

        
        switch tilemap.orientation {
            
        case .Orthogonal:
            coord = CGPoint(x: position.x / tileSize.width,
                            y: position.y / -tileSize.height)
            
        case .Isometric:
            coord = CGPoint(x: ((position.x / tileSizeHalved.width) + (position.y / -tileSizeHalved.height)) / 2,
                            y: ((position.y / -tileSizeHalved.height) - (position.x / tileSizeHalved.width)) / 2)
        }
        
        if mustBeValid && !isValidCoord(x: Int(floor(coord.x)), y: Int(floor(coord.y))) {
            return nil
        }
        
        if round {
            return CGPoint(x: Int(floor(coord.x)), y: Int(floor(coord.y)))
        }
        
        return coord
    }
    
    #if os(iOS)
    /** Returns the coordinate of a tile using a touch position. 
        If the position gets converted to a coordinate that is not valid nil is returned.  Otherwise the tile 
        coordinate is returned. 
        A custom offset point can be passed to this function which is useful if the tileset being used has an offset.
        Passing the round parameter as true will return a whole number coordinate (the default), or a decimal number 
        which can be used to determine where exactly within the tile the layer position is. */
    func coordAtTouchPosition(touch: UITouch, offset: CGPoint = CGPoint.zero, round: Bool = true) -> CGPoint? {
        return coordAtPosition(positionInLayer: touch.location(in: self), offset: offset, round: round)
    }
    #endif
    
    #if os(OSX)
    /** Returns the coordinate of a tile using a mouse position.
        If the position gets converted to a coordinate that is not valid nil is returned.  Otherwise the tile
        coordinate is returned.
        A custom offset point can be passed to this function which is useful if the tileset being used has an offset.
        Passing the round parameter as true will return a whole number coordinate (the default), or a decimal number
        which can be used to determine where exactly within the tile the layer position is. */
    func coordAtMousePosition(event: NSEvent, offset: CGPoint = CGPointZero, round: Bool = true) -> CGPoint? {
        return coordAtPosition(event.locationInNode(self), offset: offset, round: round)
    }
    #endif
    
    /** Returns the coord of a tile at a given screen (view) position. */
    func coordAtScreenPosition(position: CGPoint, offset: CGPoint = CGPoint.zero, round: Bool = true, mustBeValid: Bool = true) -> CGPoint? {
        
        guard let scene = self.scene, let view = scene.view else {
            print("SKTilemapLayer: Error, Not connected to scene/view.")
            return nil
        }
        
        let scenePosition = view.convert(position, to: scene)
        let layerPosition = convert(scenePosition, from: scene)
        return coordAtPosition(positionInLayer: layerPosition, offset: offset, round: round, mustBeValid: mustBeValid)
    }
    
    /** Will hide tiles outside of the set bounds rectangle. If no bounds is set the view bounds is used. 
        Increase the tileBufferSize to draw more tiles outside of the bounds. This can stop tiles that are part
        way in/out of the bounds to get fully displayed. Not giving a tileBufferSize will default it to 2.
        Scale is used for when you're expecting the layer to be scaled to anything other than 1.0. If you use a camera
        with a zoom for example, you would want to pass the zoom level (or scale of the camera) in here. */
    func clipTilesOutOfBounds(bounds: CGRect? = nil, scale: CGFloat = 1.0, tileBufferSize: CGFloat = 2) {
        
        /* The bounds passed in should assume an origin in the bottom left corner. If no bounds are passed in the size
           of the view is used. */
        var viewBounds: CGRect
        
        if bounds == nil {
            
            if scene != nil && scene?.view != nil {
                viewBounds = scene!.view!.bounds
            } else {
                print("SKTilemapLayer: Failed to clip tiles out of bounds. There is no view. Has the tilemap been added to the scene?")
                return
            }
            
        } else {
            
            viewBounds = bounds!
        }
        
        let fromX = Int(viewBounds.origin.x - (tileSize.width * tileBufferSize))
        let fromY = Int(viewBounds.origin.y - (tileSize.height * tileBufferSize))
        
        if let tile = tileAtScreenPosition(position: CGPoint(x: fromX, y: fromY)) where !previouslyShownTiles.isEmpty {
            if tile == previouslyShownTiles[0] { return }
        }
        
        let toX = Int(viewBounds.origin.x + viewBounds.width + (tileSize.width * tileBufferSize))
        let toY = Int(viewBounds.origin.y + viewBounds.height + (tileSize.height * tileBufferSize))
        let yStep = Int(tileSizeHalved.height * scale)
        let xStep = Int(tileSizeHalved.width * scale)
        
        previouslyShownTiles.forEach( { $0.isHidden = true } )
        previouslyShownTiles = []
        
        for y in stride(from: fromY, to: toY, by: yStep) {
            for x in stride(from: fromX, to: toX, by: xStep) {
                
                if let tile = tileAtScreenPosition(position: CGPoint(x: x, y: y)) {
                    tile.isHidden = false
                    previouslyShownTiles.append(tile)
                }
            }
        }
    }
}
