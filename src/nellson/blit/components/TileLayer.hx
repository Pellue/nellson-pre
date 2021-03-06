package nellson.blit.components;

import nme.geom.Matrix;
import haxe.Public;
import nme.display.Bitmap;
import nme.display.BitmapData;
import nme.display.BlendMode;
import nme.display.DisplayObject;
import nme.display.Graphics;
import nme.display.Sprite;
import nme.geom.Rectangle;
import nme.Lib;

/**
 * A little wrapper of NME's Tilesheet rendering (for native platform)
 * and using Bitmaps for Flash platform.
 * Features basic containers (TileGroup) and spritesheets animations.
 * @author Philippe / http://philippe.elsass.me
 */
class TileLayer extends TileGroup
{
	static var synchronizedElapsed:Float;

	public var view:Sprite;
	public var useSmoothing:Bool;
	public var useAdditive:Bool;
	public var useAlpha:Bool;
	public var useTransforms:Bool;
	public var useTint:Bool;

	public var tilesheet:ITilesheet;
	var drawList:DrawList;

	public function new(tilesheet:ITilesheet, smooth:Bool=true, additive:Bool=false)
	{
		super();

		view = new Sprite();
		view.mouseEnabled = false;
		view.mouseChildren = false;

		this.tilesheet = tilesheet;
		useSmoothing = smooth;
		useAdditive = additive;
		useAlpha = true;
		useTransforms = true;

		init(this);
		drawList = new DrawList();
	}

	public function render(?elapsed:Int)
	{
		drawList.begin(elapsed == null ? 0 : elapsed, useTransforms, useAlpha, useTint, useAdditive);
		renderGroup(this, 0, 0, 0);
		drawList.end();
		#if (flash||js)
		view.addChild(container);
		#else
		view.graphics.clear();
		tilesheet.drawTiles(view.graphics, drawList.list, useSmoothing, drawList.flags);
		#end
		return drawList.elapsed;
	}

	function renderGroup(group:TileGroup, index:Int, gx:Float, gy:Float)
	{
		var list = drawList.list;
		var fields = drawList.fields;
		var offsetTransform = drawList.offsetTransform;
		var offsetRGB = drawList.offsetRGB;
		var offsetAlpha = drawList.offsetAlpha;
		var elapsed = drawList.elapsed;

		#if (flash||js)
		group.container.x = gx + group.x;
		group.container.y = gy + group.y;
		var blend = useAdditive ? BlendMode.ADD : BlendMode.NORMAL;
		#else
		gx += group.x;
		gy += group.y;
		#end

		var n = group.numChildren;
		for(i in 0...n)
		{
			var child = group.children[i];
			if (child.animated) child.step(elapsed);

			#if (flash||js)
			var group:TileGroup = Std.is(child, TileGroup) ? cast child : null;
			#else
			if (!child.visible) 
				continue;
			var group:TileGroup = cast child;
			#end

			if (group != null) 
			{
				index = renderGroup(group, index, gx, gy);
			}
			else 
			{
				var sprite:TileSprite = cast child;

				#if (flash||js)
				if (sprite.visible && sprite.alpha > 0.0)
				{
					var m = sprite.bmp.transform.matrix;
					m.identity();
					m.concat(sprite.matrix);
					m.translate(sprite.x, sprite.y);
					sprite.bmp.transform.matrix = m;
					sprite.bmp.blendMode = blend;
					sprite.bmp.alpha = sprite.alpha;
					sprite.bmp.visible = true;
					// TODO apply tint
				}
				else sprite.bmp.visible = false;

				#else
				if (sprite.alpha <= 0.0) continue;
				list[index] = sprite.x + gx;
				list[index+1] = sprite.y + gy;
				list[index+2] = sprite.indice;
				if (offsetTransform > 0) {
					var t = sprite.transform;
					list[index+offsetTransform] = t[0];
					list[index+offsetTransform+1] = t[1];
					list[index+offsetTransform+2] = t[2];
					list[index+offsetTransform+3] = t[3];
				}
				if (offsetRGB > 0) {
					list[index+offsetRGB] = sprite.r;
					list[index+offsetRGB+1] = sprite.g;
					list[index+offsetRGB+2] = sprite.b;
				}
				if (offsetAlpha > 0) list[index+offsetAlpha] = sprite.alpha;
				index += fields;
				#end
			}
		}
		drawList.index = index;
		return index;
	}
}
