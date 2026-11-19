import AppKit
import Foundation
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for size in [16,32,64,128,256,512,1024] {
 let image = NSImage(size: NSSize(width:size,height:size))
 image.lockFocus()
 let s=CGFloat(size)
 NSColor(calibratedWhite:0.08,alpha:1).setFill()
 NSBezierPath(roundedRect:NSRect(x:0,y:0,width:s,height:s),xRadius:s*0.22,yRadius:s*0.22).fill()
 let rows=["1111001111","1001001000","1001001000","1111001111","1000000001","1000000001","1000001111"]
 let cell=s*0.069, dot=s*0.043
 for (row,line) in rows.enumerated() {
  for (col,bit) in line.enumerated() where bit == "1" {
   (col < 4 ? NSColor(calibratedRed:1,green:0.4,blue:0.2,alpha:1) : NSColor(calibratedWhite:0.92,alpha:1)).setFill()
   NSBezierPath(ovalIn:NSRect(x:s*0.17+CGFloat(col)*cell,y:s*0.70-CGFloat(row)*cell,width:dot,height:dot)).fill()
  }
 }
 image.unlockFocus()
 let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
 let data=bitmap.representation(using:.png,properties:[:])!
 let name = size == 1024 ? "icon_512x512@2x.png" : "icon_\(size)x\(size).png"
 try data.write(to:out.appendingPathComponent(name))
}
