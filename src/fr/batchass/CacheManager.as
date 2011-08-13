package fr.batchass
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.*;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Matrix;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	import mx.core.FlexGlobals;
	
	public class CacheManager implements IEventDispatcher
	{
		private var dispatcher:EventDispatcher;
		private var _cacheDir:File;
		private static var instance:CacheManager;
		private static var pendingDictionaryByLoader:Dictionary = new Dictionary();
		private static var pendingDictionaryByCacheFile:Dictionary = new Dictionary();
		private static var pendingDictionaryByURL:Dictionary = new Dictionary();
		private const THUMBS_PATH:String = "thumbs";
		private const CLIPS_PATH:String = "clips";
		private const SWF_PATH:String = "preview";
		private static var timer:Timer;
		private static var busy:Boolean = false;		
		private static var filesToDownload:Array = new Array();
		private static const minFileSize:int = 10000;
		[Bindable]
		public var filesRemaining:int = 0;
		
		public function CacheManager( cacheDir:String )
		{
			_cacheDir = File.documentsDirectory.resolvePath( cacheDir );
			Util.log( "CacheManager, constructor, cachedir: " + cacheDir );
			dispatcher = new EventDispatcher(this);
			timer = new Timer(1000);
			timer.addEventListener(TimerEvent.TIMER, processQueue);
			timer.start();
			Util.log( "CacheManager, constructor, timer started" );
		}
		
		public static function getInstance( cacheDir:String ):CacheManager
		{
			if (instance == null)
			{
				instance = new CacheManager( cacheDir );
			}
			
			return instance;
		}
		public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void{
			dispatcher.addEventListener(type, listener, useCapture, priority);
		}
		
		public function dispatchEvent(evt:Event):Boolean{
			return dispatcher.dispatchEvent(evt);
		}
		
		public function hasEventListener(type:String):Boolean{
			return dispatcher.hasEventListener(type);
		}
		
		public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void{
			dispatcher.removeEventListener(type, listener, useCapture);
		}
		
		public function willTrigger(type:String):Boolean {
			return dispatcher.willTrigger(type);
		}
		private function processQueue(event:Event): void 
		{
			filesRemaining = filesToDownload.length;
			if ( !busy )
			{
				if ( filesRemaining > 0 )
				{
					busy = true;
					Util.log( "CacheManager, processQueue, filesToDownload.length: " + filesRemaining );
					addFileToCache( filesToDownload[0].sUrl, filesToDownload[0].lUrl );
					filesToDownload.shift();
				}
				else
				{
					dispatchEvent( new Event(Event.COMPLETE) );
				}	
			}
		}
		public function getThumbnailByURL( thumbnailUrl:String ):String
		{
			var localUrl:String = _cacheDir.nativePath + File.separator + THUMBS_PATH + File.separator + Util.getFileNameFromFormerSlash( thumbnailUrl ) ;
			var cacheFile:File = new File( localUrl );
			
			Util.log( "CacheManager, getThumbnailByURL localUrl: " + localUrl );
			if( cacheFile.exists )
			{
				Util.log( "CacheManager, getThumbnailByURL cacheFile exists: " + cacheFile.url );
				return cacheFile.url;
			} 
			else 
			{
				Util.log( "CacheManager, getThumbnailByURL cacheFile does not exist: " + thumbnailUrl );
				filesToDownload.push({sUrl:thumbnailUrl,lUrl:localUrl});				
				return thumbnailUrl;
			}
		}
		public function getClipByURL( assetUrl:String, force:Boolean=false ):String
		{
			var localUrl:String = _cacheDir.nativePath + File.separator + CLIPS_PATH + File.separator + Util.getFileNameFromFormerSlash( assetUrl ) ;
			return localUrl;
		}
		public function downloadClipFiles( thumbnailUrl:String, assetUrl:String, swfUrl:String ):void
		{			
			var tUrl:String = _cacheDir.nativePath + File.separator + THUMBS_PATH + File.separator + Util.getFileNameFromFormerSlash( thumbnailUrl ) ;
			var tCacheFile:File = new File( tUrl );
			var sUrl:String = _cacheDir.nativePath + File.separator + SWF_PATH + File.separator + Util.getFileNameFromFormerSlash( swfUrl ) ;
			var sCacheFile:File = new File( sUrl );
			var cUrl:String = _cacheDir.nativePath + File.separator + CLIPS_PATH + File.separator + Util.getFileNameFromFormerSlash( assetUrl ) ;
			var cCacheFile:File = new File( cUrl );
			
			Util.cacheLog( "CacheManager, downloadClipFiles thumb localUrl: " + tUrl );
			if( tCacheFile.exists )
			{
				Util.cacheLog( "CacheManager, downloadClipFiles thumb cacheFile exists: " + tCacheFile.url );
			} 
			else 
			{
				Util.cacheLog( "CacheManager, downloadClipFiles thumb cacheFile does not exist: " + thumbnailUrl );
				addFileToDownload( thumbnailUrl, tUrl );			
			}	
			if ( sCacheFile.exists )
			{
				if ( sCacheFile.size < minFileSize )
				{			
					Util.cacheLog( "CacheManager, downloadClipFiles sUrl size < " + minFileSize );
					addFileToDownload( assetUrl, cUrl );
					addFileToDownload( swfUrl, sUrl);
				}
			}
			else
			{
				Util.cacheLog( "CacheManager, downloadClipFiles does not exist " + sUrl );
				addFileToDownload( assetUrl, cUrl );
				addFileToDownload( swfUrl, sUrl);			
			}			
		}
		public function addFileToDownload( assetUrl:String, localUrl:String):void
		{
			var found:Boolean = false;
			if ( filesToDownload.length > 0 )
			{
				for ( var i:int = 0; i < filesToDownload.length; i++)
				{
					if ( filesToDownload[i].sUrl == assetUrl ) found = true;
				}				
			}
			
			if ( !found )
			{
				Util.cacheLog( "CacheManager, addFileToDownload not in queue: " + assetUrl );
				filesToDownload.push({sUrl:assetUrl,lUrl:localUrl});
			}
		}
		public function getSwfByURL( assetUrl:String, macOs:Boolean ):String
		{
			var localUrl:String; 
			// added june 2011: "file://" for mac
			if ( macOs ) localUrl = "file://" else localUrl = "";
			localUrl += _cacheDir.nativePath + File.separator + SWF_PATH + File.separator + Util.getFileNameFromFormerSlash( assetUrl ) ;
			return localUrl;
		}
		// download image for gallery
		public function getGalleryImageByURL( url:String, width:int, height:int ):String
		{
			var fileName:String = width.toString() + 'x' + height.toString() + '_' + Util.getFileName( url );
			var localUrl:String = _cacheDir.nativePath + File.separator + THUMBS_PATH + File.separator + fileName;
			var cacheFile:File = new File( localUrl );
			
			Util.log( "CacheManager, getGalleryImageByURL localUrl: " + localUrl );
			if( cacheFile.exists )
			{
				Util.log( "CacheManager, getGalleryImageByURL cacheFile exists: " + cacheFile.url );
			} 
			else 
			{
				Util.log( "CacheManager, getGalleryImageByURL cacheFile does not exist: " + url );
				addGalleryImageToCache( url, width, height );
			}
			return fileName;
		}
		private function addFileToCache( url:String, localUrl:String ):void
		{
			var cacheFile:File = new File( localUrl );
			
			Util.log( "CacheManager, addFileToCache localUrl: " + localUrl );
			if(!pendingDictionaryByURL[url])
			{
				FlexGlobals.topLevelApplication.statusText.text = 'File added to download queue: ' + url;
				Util.log( "CacheManager, addFileToCache url: " + url );
				var req:URLRequest = new URLRequest(url);
				var loader:URLLoader = new URLLoader();
				loader.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
				loader.addEventListener( SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler );
				loader.addEventListener( HTTPStatusEvent.HTTP_STATUS, httpStatusHandler );
				loader.addEventListener( ErrorEvent.ERROR, errorEventErrorHandler );
				loader.addEventListener( Event.COMPLETE, fileLoadComplete );
				loader.dataFormat = URLLoaderDataFormat.BINARY;
				loader.load(req);
				pendingDictionaryByLoader[loader] = url;
				pendingDictionaryByCacheFile[loader] = localUrl;
				pendingDictionaryByURL[url] = true;
			} 
		}
		
		private function addAssetToCache( url:String, displayInDefaultApp:Boolean = false ):void
		{
			if(!pendingDictionaryByURL[url]){
				var req:URLRequest = new URLRequest(url);
				var loader:URLLoader = new URLLoader();
				loader.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
				loader.addEventListener( SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler );
				loader.addEventListener( ErrorEvent.ERROR, errorEventErrorHandler );
				loader.addEventListener( HTTPStatusEvent.HTTP_STATUS, httpStatusHandler );
				if ( displayInDefaultApp )
				{
					loader.addEventListener( Event.COMPLETE, assetLoadCompleteAndShow );
				}
				else
				{
					loader.addEventListener( Event.COMPLETE, assetLoadComplete );
				}
				loader.dataFormat = URLLoaderDataFormat.BINARY;
				loader.load(req);
				pendingDictionaryByLoader[loader] = url;
				pendingDictionaryByURL[url] = true;
			} 
		}
		private function addGalleryImageToCache( url:String, width:Number, height:int ):void
		{
			var localUrlPath:String = width.toString() + 'x' + height.toString() + '_' + url;
			if(!pendingDictionaryByURL[localUrlPath]){
				var req:URLRequest = new URLRequest(url);
				var loader:Loader = new Loader();
				
				loader.contentLoaderInfo.addEventListener ( Event.COMPLETE, galleryImageLoadComplete ) ;
				loader.contentLoaderInfo.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler ) ; 
				
				loader.load(req);
				pendingDictionaryByLoader[loader.contentLoaderInfo] = localUrlPath;
				pendingDictionaryByURL[localUrlPath] = true;
			} 
		}
		private function fileLoadComplete( event:Event ):void
		{
			var loader:URLLoader = event.target as URLLoader;
			var url:String = pendingDictionaryByLoader[loader];
			Util.log( "CacheManager, addFileToCache fileLoadComplete: " + url );
			
			var cacheFile:File = new File( pendingDictionaryByCacheFile[loader] );
			Util.log( "CacheManager, addFileToCache cacheFile: " + pendingDictionaryByCacheFile[loader] );
			Util.log( "CacheManager, addFileToCache cacheFile.url: " + cacheFile.url );
			var stream:FileStream = new FileStream();
			cacheFile.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
			stream.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
			stream.open(cacheFile,FileMode.WRITE);
			stream.writeBytes(loader.data);
			stream.close();
			FlexGlobals.topLevelApplication.statusText.text = 'File downloaded: ' + url;
			
			delete pendingDictionaryByLoader[loader];
			delete pendingDictionaryByCacheFile[loader];
			delete pendingDictionaryByURL[url];
			filesRemaining = filesToDownload.length;
			busy = false;
		}
		
		
		private function assetLoadComplete( event:Event ):void
		{
			var loader:URLLoader = event.target as URLLoader;
			var url:String = pendingDictionaryByLoader[loader];
			
			var cacheFile:File = new File( _cacheDir.nativePath + File.separator + CLIPS_PATH + File.separator + Util.getFileNameFromFormerSlash( url ) );
			var stream:FileStream = new FileStream();
			cacheFile.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
			stream.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
			stream.open(cacheFile,FileMode.WRITE);
			stream.writeBytes(loader.data);
			stream.close();
			
			delete pendingDictionaryByLoader[loader];
			delete pendingDictionaryByURL[url];
		}
		private function assetLoadCompleteAndShow( event:Event ):void
		{
			var loader:URLLoader = event.target as URLLoader;
			var url:String = pendingDictionaryByLoader[loader];
			
			var cacheFile:File = new File( _cacheDir.nativePath + File.separator + CLIPS_PATH + File.separator + Util.getFileNameFromFormerSlash( url ) );
			var stream:FileStream = new FileStream();
			cacheFile.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
			stream.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
			stream.open(cacheFile,FileMode.WRITE);
			stream.writeBytes(loader.data);
			stream.close();
			cacheFile.openWithDefaultApplication();
			
			delete pendingDictionaryByLoader[loader];
			delete pendingDictionaryByURL[url];
		}
		//generate resized images
		private function galleryImageLoadComplete( event:Event ):void
		{
			var loader:LoaderInfo = event.target as LoaderInfo;
			var passedUrl:String = pendingDictionaryByLoader[loader];
			var indexOfX:int = passedUrl.indexOf( 'x');
			var indexOfUD:int = passedUrl.indexOf( '_');
			var url:String = passedUrl.substr( indexOfUD + 1 );
			var w:String = passedUrl.substr( 0, indexOfX );
			var h:String = passedUrl.substr( indexOfX + 1, indexOfUD - indexOfX - 1 );
			var fileName:String = w + 'x' + h + '_' + Util.getFileName( url );
			var cacheFile:File = new File( _cacheDir.nativePath + File.separator + THUMBS_PATH + File.separator + fileName );
			var stream:FileStream = new FileStream();
			
			var originalImage:Bitmap = Bitmap(loader.content);
			var scale:Number = int(w) / originalImage.width;
			var newHeight:Number = originalImage.height * scale;
			var pixelsResized:BitmapData = new BitmapData( int(w), Math.min( int(h), newHeight ), true);
			pixelsResized.draw(originalImage.bitmapData, new Matrix(scale, 0, 0, scale));
			
			cacheFile.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
			stream.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
			stream.open( cacheFile, FileMode.WRITE );
			stream.writeBytes( encodeJPG( pixelsResized ) );
			stream.close();
			
			delete pendingDictionaryByLoader[loader];
			delete pendingDictionaryByURL[url];
		}
		
		//jpg encoding
		private function encodeJPG( bd:BitmapData ):ByteArray
		{
			var jpgEncoder:JPGEncoder = new JPGEncoder();
			var bytes:ByteArray = jpgEncoder.encode(bd);
			return bytes;
		} 
		
		public function errorEventErrorHandler(event:ErrorEvent):void
		{
			Util.log( 'An ErrorEvent has occured: ' + event.text );
		}	
		private function ioErrorHandler( event:IOErrorEvent ):void
		{
			Util.log( 'CacheManager, An IO Error has occured: ' + event.text );
		}    
		// only called if a security error detected by flash player such as a sandbox violation
		private function securityErrorHandler( event:SecurityErrorEvent ):void
		{
			Util.log( "CacheManager, securityErrorHandler: " + event.text );
		}		
		//  after a file upload is complete or attemted the server will return an http status code, code 200 means all is good anything else is bad.
		private function httpStatusHandler( event:HTTPStatusEvent ):void 
		{   
			Util.log( "CacheManager, httpStatusHandler, status(200 is ok): " + event.status );
		}
	}
}