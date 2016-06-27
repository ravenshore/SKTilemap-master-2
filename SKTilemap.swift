/*
 SKTilemap
 SKTilemap.swift
 
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
import GameplayKit

// MARK: SKTilemapOrientation
enum SKTilemapOrientation : String {
    
    case Orthogonal = "orthogonal";
    case Isometric = "isometric";
    
    /** Change these values in code if you wish to have your tiles have a different anchor point upon layer initialization. */
    func tileAnchorPoint() -> CGPoint {
        
        switch self {
        case .Orthogonal:
            return CGPoint(x: 0.5, y: 0.5)
            
        case .Isometric:
            return CGPoint(x: 0.5, y: 0.5)
        }
    }
}

// MARK: SKTilemap
class SKTilemap : SKNode {
    
//MARK: Properties
    
    /** Properties shared by all TMX object types. */
    var properties: [String : String] = [:]
    
    /** The current version of the tilemap. */
    var version: Double = 0
    
    /** The dimensions of the tilemap in tiles. */
    let size: CGSize
    private var sizeHalved: CGSize { get { return CGSize(width: width / 2, height: height / 2) } }
    var width: Int { return Int(size.width) }
    var height: Int { return Int(size.height) }
    
    /** The size of the grid for the tilemap. Note that tilesets may have differently sized tiles. */
    let tileSize: CGSize
    private var tileSizeHalved: CGSize { get { return CGSize(width: tileSize.width / 2, height: tileSize.height / 2) } }
    
    /** The orientation of the tilemap. See SKTilemapOrientation for valid orientations. */
    let orientation: SKTilemapOrientation
    
    /** The tilesets this tilemap contains. */
    private var tilesets: Set<SKTilemapTileset> = []
    
    /** The layers this tilemap contains. */
    private var tileLayers: Set<SKTilemapLayer> = []
    
    /** The object groups this tilemap contains */
    private var objectGroups: Set<SKTilemapObjectGroup> = []
    
    /** The display bounds the viewable area of this tilemap should be constrained to. Tiles positioned outside this 
        rectangle will not be shown. This should speed up performance for large tilemaps when tile clipping is enabled. 
        If this property is set to nil, the SKView bounds will be used instead as default. */
    var displayBounds: CGRect?
    
    /** Internal property for the layer alignment. */
    private var layerAlignment = CGPoint(x: 0.5, y: 0.5)

    /** Used to set how the layers are aligned within the map much like an anchorPoint on a sprite node.
    + 0 - The layers left/bottom most edge will rest at 0 in the scene
    + 0.5 - The center of the layer will rest at 0 in the scene
    + 1 - The layers right/top most edge will rest at 0 in the scene */
    var alignment: CGPoint {
        get { return layerAlignment }
        set {
            self.layerAlignment = newValue
            tileLayers.forEach({ self.alignLayer(layer: $0) })
        }
    }
    
    /** Internal var for whether tile clipping is enabled or disabled. */
    private var useTileClipping = false
    
    /** Enables tile clipping on this tilemap. */
    var enableTileClipping: Bool {
        get { return useTileClipping }
        set {
            
            if newValue == true {
                
                if displayBounds == nil && scene == nil && scene?.view == nil {
                    print("SKTiledMap: Failed to enable tile clipping. Tilemap not added to Scene and no Display Bounds set.")
                    useTileClipping = false
                    return
                }
                else if (scene != nil && scene?.view != nil) || displayBounds != nil {
                    
                    for y in 0..<height {
                        for x in 0..<width {
                            for layer in tileLayers {
                                if let tile = layer.tileAtCoord(x: x, y) {
                                    tile.isHidden = true
                                }
                            }
                        }
                    }
                    
                    print("SKTilemap: Tile clipping enabled.")
                    useTileClipping = true
                    clipTilesOutOfBounds(tileBufferSize: 1)
                }
            } else {
                
                for y in 0..<height {
                    for x in 0..<width {
                        for layer in tileLayers {
                            if let tile = layer.tileAtCoord(x: x, y) {
                                tile.isHidden = false
                            }
                        }
                    }
                }
                
                print("SKTilemap: Tile clipping disabled.")
                useTileClipping = false
            }
        }
    }
    
    /** When tile clipping is enabled this property will disable it when the scale passed in goes below this threshold.
        This is important because the tile clipping can cause serious slow down when a lot of tiles are drawn on screen.
        Experiment with this value to see what's best for your map.
        This is only needed if you plan on scaling the tilemap.*/
    var minTileClippingScale: CGFloat = 0.6
    private var disableTileClipping = false
    
    /** The graph used for path finding around the tilemap. To initialize it implement one of the SKTilemapPathFindingProtocol
        functions. */
    var pathFindingGraph: GKGridGraph<GKGridGraphNode>?
    var removedGraphNodes: [GKGridGraphNode] = []
    
    /** Returns the next available global ID to use. Useful for adding new tiles to a tileset or working out a tilesets
        first GID property. */
    var nextGID: Int {
        
        var highestGID = 0
        
        for tileset in tilesets {
            if tileset.lastGID > highestGID {
                highestGID = tileset.lastGID
            }
        }
        
        return highestGID + 1
    }
    
// MARK: Initialization
    
    /** Initialize an empty tilemap object. */
    init(name: String, size: CGSize, tileSize: CGSize, orientation: SKTilemapOrientation) {
        
        self.size = size
        self.tileSize = tileSize
        self.orientation = orientation
        
        super.init()
        
        self.name = name
    }
    
    /** Initialize a tilemap from tmx parser attributes. Should probably only be called by SKTilemapParser. */
    init?(filename: String, tmxParserAttributes attributes: [String : String]) {
        
        guard
            let version = attributes["version"] where (Double(version) != nil),
            let width = attributes["width"] where (Int(width) != nil),
            let height = attributes["height"] where (Int(height) != nil),
            let tileWidth = attributes["tilewidth"] where (Int(tileWidth) != nil),
            let tileHeight = attributes["tileheight"] where (Int(tileHeight) != nil),
            let orientation = attributes["orientation"] where (SKTilemapOrientation(rawValue: orientation) != nil)
            else {
                print("SKTilemap: Failed to initialize with tmxAttributes.")
                return nil
        }
        
        self.version = Double(version)!
        self.orientation = SKTilemapOrientation(rawValue: orientation)!
        size = CGSize(width: Int(width)!, height: Int(height)!)
        tileSize = CGSize(width: Int(tileWidth)!, height: Int(tileHeight)!)
        
        super.init()
        
        self.name = filename
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /** Loads a tilemap from .tmx file. */
    class func loadTMX(name: String) -> SKTilemap? {
        let time = NSDate()
        
        if let tilemap = SKTilemapParser().loadTilemap(filename: name) {
            tilemap.printDebugDescription()
            print("\nSKTilemap: Loaded tilemap '\(name)' in \(NSDate().timeIntervalSince(time as Date)) seconds.")
            return tilemap
        }
        
        print("SKTilemap: Failed to load tilemap '\(name)'.")
        return nil
    }
    
// MARK: Debug
    func printDebugDescription() {
        
        print("\nTilemap: \(name!) (\(version)), Size: \(size), TileSize: \(tileSize), Orientation: \(orientation)")
        print("Properties: \(properties)")
        
        for tileset in tilesets { tileset.printDebugDescription() }
        for tileLayer in tileLayers { tileLayer.printDebugDescription() }
        for objectGroup in objectGroups { objectGroup.printDebugDescription() }
    }
    
// MARK: Tilesets
    
    /** Adds a tileset to the tilemap. Returns nil on failure. (A tileset with the same name already exists). Or 
        or returns the tileset. */
    func add(tileset: SKTilemapTileset) -> SKTilemapTileset? {
        
        if tilesets.contains({ $0.hashValue == tileset.hashValue }) {
            print("SKTilemap: Failed to add tileset. A tileset with the same name already exists.")
            return nil
        }
        
        tilesets.insert(tileset)
        return tileset
    }
    
    /** Returns a tileset with specified name or nil if it doesn't exist. */
    func getTileset(name: String) -> SKTilemapTileset? {
        
        if let index = tilesets.index( where: { $0.name == name } ) {
            return tilesets[index]
        }
        
        return nil
    }
    
    /** Will return a SKTilemapTileData object with matching id from one of the tilesets associated with this tilemap
        or nil if no match can be found. */
    func getTileData(id: Int) -> SKTilemapTileData? {
        
        for tileset in tilesets {
            
            if let tileData = tileset.getTileData(id: id) {
                return tileData
            }
        }
        
        return nil
    }
    
// MARK: Tile Layers
    
    /** Adds a tile layer to the tilemap. A zPosition can be supplied and will be applied to the layer. If no zPosition
        is supplied, the layer is assumed to be placed on top of all others. Returns nil on failure. (A layer with the
        same name already exists. Or returns the layer. */
    func add(tileLayer: SKTilemapLayer, zPosition: CGFloat? = nil) -> SKTilemapLayer? {
        
        if tileLayers.contains({ $0.hashValue == tileLayer.hashValue }) {
            print("SKTilemap: Failed to add tile layer. A tile layer with the same name already exists.")
            return nil
        }
        
        if zPosition != nil {
            tileLayer.zPosition = zPosition!
        } else {
            
            var highestZPosition: CGFloat?
            
            for layer in tileLayers {
                
                if highestZPosition == nil {
                    highestZPosition = layer.zPosition
                }
                else if layer.zPosition > highestZPosition {
                    highestZPosition = layer.zPosition
                }
            }
            
            if highestZPosition == nil { highestZPosition = -1 }
            tileLayer.zPosition = highestZPosition! + 1
        }
        
        tileLayers.insert(tileLayer)
        addChild(tileLayer)
        alignLayer(layer: tileLayer)
        return tileLayer
    }
    
    /** Positions a tilemap layer so that its center position is resting at the tilemaps 0,0 position. */
    private func alignLayer(layer: SKTilemapLayer) {

        var position = CGPoint.zero
        
        if orientation == .Orthogonal {
            let sizeInPoints = CGSize(width: size.width * tileSize.width, height: size.height * tileSize.height)
            position.x = -sizeInPoints.width * alignment.x
            position.y = sizeInPoints.height - alignment.y * sizeInPoints.height
        }
        
        if orientation == .Isometric {
            
            let sizeInPoints = CGSize(width: (size.width + size.height) * tileSize.width, height: (size.width + size.height) * tileSize.height)
            position.x = ((sizeHalved.width - sizeHalved.height) * tileSize.width) - alignment.x * (sizeInPoints.width / 2)
            position.y = ((sizeHalved.width + sizeHalved.height) * tileSize.height) - alignment.y * (sizeInPoints.height / 2)
            
            print(position.x)
        
        }
        
        layer.position = position
        
        /* Apply the layers offset */
        layer.position.x += (layer.offset.x + layer.offset.x * orientation.tileAnchorPoint().x)
        layer.position.y -= (layer.offset.y - layer.offset.y * orientation.tileAnchorPoint().y)
    }
    
    /* Get all layers in a set. */
    func getLayers() -> Set<SKTilemapLayer> {
        return tileLayers
    }
    
    /** Returns a tilemap layer with specified name or nil if one does not exist. */
    func getLayer(name: String) -> SKTilemapLayer? {
        
        if let index = tileLayers.index( where: { $0.name == name } ) {
            return tileLayers[index]
        }
        
        return nil
    }
    
    /** Returns "any" tilemap layer. Useful if you want access to functions within a layer and not bothered which layer
        it is. In reality this just returns the first tilemap layer that was added. Can return nil if there are no layers. */
    func anyLayer() -> SKTilemapLayer? {
        return tileLayers.first
    }
    
    /** Removes a layer from the tilemap. The layer removed is returned or nil if the layer wasn't found. */
    func removeLayer(name: String) -> SKTilemapLayer? {
        
        if let layer = getLayer(name: name) {
            
            layer.removeFromParent()
            tileLayers.remove(layer)
            return layer
        }
        
        return nil
    }
    
    /** Will "clip" tiles outside of the tilemaps 'displayBounds' property if set or the SKView bounds (if it's a child
        of a view... which it should be). 
        You must call this function when ever you reposition the tilemap so it can update the visible tiles. 
        For example in a scenes TouchesMoved function if scrolling the tilemap with a touch or mouse. */
    func clipTilesOutOfBounds(scale: CGFloat = 1.0, tileBufferSize: CGFloat = 2) {
        
        if !useTileClipping && disableTileClipping == false { return }
        
        if scale < minTileClippingScale && disableTileClipping == false {
            disableTileClipping = true
            enableTileClipping = false
        }
        
        if scale >= minTileClippingScale && disableTileClipping == true {
            disableTileClipping = false
            enableTileClipping = true
        }
        
        if disableTileClipping { return }
        
        for layer in tileLayers {
            layer.clipTilesOutOfBounds(bounds: displayBounds, scale: scale, tileBufferSize: tileBufferSize)
        }
    }
    
// MARK: Object Groups
    
    /** Adds an object group to the tilemap. Returns nil on failure. (An object group with the same name already exists.
        Or returns the object group. */
    func add(objectGroup: SKTilemapObjectGroup) -> SKTilemapObjectGroup? {
        
        if objectGroups.contains({ $0.hashValue == objectGroup.hashValue }) {
            print("SKTilemap: Failed to add object layer. An object layer with the same name already exists.")
            return nil
        }
        
        objectGroups.insert(objectGroup)
        return objectGroup
    }
    
    /** Returns a object group with specified name or nil if it does not exist. */
    func getObjectGroup(name: String) -> SKTilemapObjectGroup? {
        
        if let index = objectGroups.index( where: { $0.name == name } ) {
            return objectGroups[index]
        }
        
        return nil
    }
}
