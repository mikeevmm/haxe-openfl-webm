package webm;
import cpp.Lib;
import cpp.vm.Gc;
import haxe.io.Bytes;
import haxe.io.BytesData;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.PixelSnapping;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.SampleDataEvent;
import flash.media.Sound;
import flash.utils.ByteArray;
import flash.utils.Endian;
import webm.internal.WebmUtils;

class WebmPlayer extends EventDispatcher {
	var webm:Webm;
	var io:WebmIo;
	var targetSprite:Sprite;
	var bitmap:Bitmap;
	var bitmapData:BitmapData;
	var decoder:Dynamic;
	var startTime:Float = 0;
	var lastDecodedVideoFrame:Float = 0;
	var playing:Bool = false;
	var renderedCount:Int = 0;
	
	public var width:Int;
	public var height:Int;
	public var frameRate:Float;
	public var duration:Float;

	public function new(io:WebmIo, targetSprite:Sprite) {
		super();
		this.io = io;
		this.targetSprite = targetSprite;
		this.webm = new Webm();
		this.decoder = hx_webm_decoder_create(io.io);
		var info = hx_webm_decoder_get_info(this.decoder);
		this.width = info[0];
		this.height = info[1];
		this.frameRate = info[2];
		this.duration = info[3];
		this.bitmapData = new BitmapData(this.width, this.height);
		this.bitmap = new Bitmap(this.bitmapData, PixelSnapping.AUTO, true);
		targetSprite.addChild(this.bitmap);
	}
	
	public function getElapsedTime():Float {
		return haxe.Timer.stamp() - this.startTime;
	}
	
	public function play() {
		if (!playing) {
			this.startTime = haxe.Timer.stamp();
			
			targetSprite.addEventListener(Event.ENTER_FRAME, onSpriteEnterFrame);
			playing = true;
			this.dispatchEvent(new Event(WebmEvent.PLAY));
		}
	}

	public function stop() {
		if (playing) {
			targetSprite.removeEventListener(Event.ENTER_FRAME, onSpriteEnterFrame);
			playing = false;
			this.dispatchEvent(new Event(WebmEvent.STOP));
		}
	}
	
	private function onSpriteEnterFrame(e:Event) {
		var startRenderedCount = renderedCount;

		while (hx_webm_decoder_has_more(decoder) && lastDecodedVideoFrame < getElapsedTime()) {
		//while (hx_webm_decoder_has_more(decoder)) {
			hx_webm_decoder_step(decoder, decodeVideoFrame);
			if (renderedCount > startRenderedCount) break;
		}
		
		if (!hx_webm_decoder_has_more(decoder)) {
			// Dispatch WebmEvent
			this.dispatchEvent(new Event(WebmEvent.END));
			
			// Stop playing
			stop();
		}
	}

	private function decodeVideoFrame(time:Float, data:BytesData):Void {
		lastDecodedVideoFrame = time;
		renderedCount++;
		
		//trace("DECODE VIDEO FRAME! " + getElapsedTime() + ":" + time);
		var decodeTime:Float = WebmUtils.measureTime(function() {
			webm.decode(ByteArray.fromBytes(Bytes.ofData(data)));
		});
		var renderTime:Float = WebmUtils.measureTime(function() {
			webm.getAndRenderFrame(this.bitmapData);
		});
		
		//trace("Profiling Times: decode=" + decodeTime + " ; render=" + renderTime);
	}
	
	static var hx_webm_decoder_create = cpp.Lib.load("openfl-webm", "hx_webm_decoder_create", 1);
	static var hx_webm_decoder_get_info = cpp.Lib.load("openfl-webm", "hx_webm_decoder_get_info", 1);
	static var hx_webm_decoder_has_more = cpp.Lib.load("openfl-webm", "hx_webm_decoder_has_more", 1);
	static var hx_webm_decoder_step = cpp.Lib.load("openfl-webm", "hx_webm_decoder_step", 2);
}