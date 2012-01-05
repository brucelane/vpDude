package
{
	import flash.filesystem.File;
	import flash.system.Capabilities;
	
	import fr.batchass.Util;
	import flash.events.Event;

	public class Session
	{
		private static var instance:Session = new Session();
		private var _connected:Boolean;
		private var _userName:String;
		// path to vpDude folder
		private var _vpFolderPath:String;
		// path to own videos folder
		private var _ownFolderPath:String;
		private var _dldFolderPath:String;
		private var _dbFolderPath:String;
		private var _os:String;	
		// ffmpeg file name depending on OS
		private var _vpFFMpeg:String;
		private var _vpFFMpegExePath:String;
		private var _vpRootUrl:String = "https://www.videopong.net/";
		private var vpDudeFiles:String = vpRootUrl + "vpdudefiles/";
		private var _vpUrl:String = vpRootUrl + "vpdude/";
		private var _vpUpUrl:String = vpRootUrl + "vpdudeup/";		
		private var _vpFullUrl:String = vpUrl;		
		private var _vpUploadUrl:String = vpUpUrl;
		
		public function Session()
		{
			if ( instance == null ) 
			{
				checkFFMpeg();			
			}
			else trace( "Session already instanciated." );
		}
		
		public static function getInstance():Session 
		{
			return instance;
		}	
		private function checkFFMpeg():void
		{
			// determine OS to download right ffmpeg
			os = Capabilities.os.substr(0, 3);
			if (os == "Win") 
			{
				vpFFMpeg = "ffmpeg.exe";
			} 
			else if (os == "Mac") 
			{
				vpFFMpeg = "ffmpeg.dat";
			} 
			else 
			{
				vpFFMpeg = "ffmpeg.lame"; 
			}
			var FFMpegAppFile:File = File.applicationDirectory.resolvePath( 'ffmpeg' + File.separator + vpFFMpeg );
			if( FFMpegAppFile.exists )
			{
				Util.log( "FFMpegAppFile exists: " + FFMpegAppFile.nativePath );
			} 
			else 
			{
				Util.log( "FFMpegAppFile does not exist: " + FFMpegAppFile.nativePath );
			}
			vpFFMpegExePath = FFMpegAppFile.nativePath;
		}
		public function get userName():String
		{
			return _userName;
		}

		public function set userName(value:String):void
		{
			_userName = value;
		}

		[Bindable]
		public function get vpFolderPath():String
		{
			return _vpFolderPath;
		}
		
		private function set vpFolderPath(value:String):void
		{
			_vpFolderPath = value;
			dldFolderPath = _vpFolderPath + File.separator + "dld";
			dbFolderPath = _vpFolderPath + File.separator + "db";
		}
		
		[Bindable]
		public function get ownFolderPath():String
		{
			return _ownFolderPath;
		}
		
		private function set ownFolderPath(value:String):void
		{
			_ownFolderPath = value;
		}

		public function get dldFolderPath():String
		{
			return _dldFolderPath;
		}

		public function set dldFolderPath(value:String):void
		{
			_dldFolderPath = value;
		}

		public function get dbFolderPath():String
		{
			return _dbFolderPath;
		}

		public function set dbFolderPath(value:String):void
		{
			_dbFolderPath = value;
		}

		public function get os():String
		{
			return _os;
		}

		public function set os(value:String):void
		{
			_os = value;
		}

		public function get vpFFMpeg():String
		{
			return _vpFFMpeg;
		}

		public function set vpFFMpeg(value:String):void
		{
			_vpFFMpeg = value;
		}

		public function get vpFFMpegExePath():String
		{
			return _vpFFMpegExePath;
		}

		public function set vpFFMpegExePath(value:String):void
		{
			_vpFFMpegExePath = value;
		}

		public function get connected():Boolean
		{
			return _connected;
		}

		public function set connected(value:Boolean):void
		{
			_connected = value;
		}

		[Bindable(event="vpFullUrlChange")]
		public function get vpFullUrl():String
		{
			return _vpFullUrl;
		}

		public function set vpFullUrl(value:String):void
		{
			if( _vpFullUrl !== value)
			{
				_vpFullUrl = value;
				dispatchEvent(new Event("vpFullUrlChange"));
			}
		}

		[Bindable(event="vpUploadUrlChange")]
		public function get vpUploadUrl():String
		{
			return _vpUploadUrl;
		}

		public function set vpUploadUrl(value:String):void
		{
			if( _vpUploadUrl !== value)
			{
				_vpUploadUrl = value;
				dispatchEvent(new Event("vpUploadUrlChange"));
			}
		}

		public function get vpUrl():String
		{
			return _vpUrl;
		}

		public function set vpUrl(value:String):void
		{
			_vpUrl = value;
		}

		public function get vpUpUrl():String
		{
			return _vpUpUrl;
		}

		public function set vpUpUrl(value:String):void
		{
			_vpUpUrl = value;
		}

		public function get vpRootUrl():String
		{
			return _vpRootUrl;
		}

		public function set vpRootUrl(value:String):void
		{
			_vpRootUrl = value;
		}


	}
}