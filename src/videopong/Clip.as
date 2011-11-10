package videopong
{
	import flash.filesystem.File;
	
	import fr.batchass.Util;
	
	import mx.core.FlexGlobals;

	public class Clip
	{
		private var _name:String;
		private var _clipPath:String;
		private var _clipModificationDate:String;
		private var _clipSize:String;
		private var _clipRelativePath:String;
		private var _clipGeneratedName:String;
		private var _clipGeneratedTitle:String;
		private var _clipGeneratedTitleWithoutExtension:String;
		private var _thumbsPath:String;
		private var _swfPath:String;
		public function Clip( lstFile:File )
		{
			name = lstFile.name;
			clipPath = lstFile.nativePath;
			clipModificationDate = lstFile.modificationDate.toUTCString();
			clipSize = lstFile.size.toString();	
			clipRelativePath = clipPath.substr( FlexGlobals.topLevelApplication.ownFolderPath.length + 1 );
			clipGeneratedName = Util.getFileNameWithSafePath( clipRelativePath );
			clipGeneratedTitle = Util.getFileName( clipRelativePath );
			clipGeneratedTitleWithoutExtension = Util.getFileNameWithoutExtension( clipRelativePath );
			thumbsPath = FlexGlobals.topLevelApplication.dldFolderPath + "/thumbs/" + clipGeneratedName + "/";
			swfPath = FlexGlobals.topLevelApplication.dldFolderPath + "/preview/" + clipGeneratedName + "/";
		}

		public function get name():String
		{
			return _name;
		}

		public function set name(value:String):void
		{
			_name = value;
		}

		public function get clipPath():String
		{
			return _clipPath;
		}

		public function set clipPath(value:String):void
		{
			_clipPath = value;
		}

		public function get clipModificationDate():String
		{
			return _clipModificationDate;
		}

		public function set clipModificationDate(value:String):void
		{
			_clipModificationDate = value;
		}

		public function get clipSize():String
		{
			return _clipSize;
		}

		public function set clipSize(value:String):void
		{
			_clipSize = value;
		}

		public function get clipRelativePath():String
		{
			return _clipRelativePath;
		}

		public function set clipRelativePath(value:String):void
		{
			_clipRelativePath = value;
		}

		public function get clipGeneratedName():String
		{
			return _clipGeneratedName;
		}

		public function set clipGeneratedName(value:String):void
		{
			_clipGeneratedName = value;
		}

		public function get clipGeneratedTitle():String
		{
			return _clipGeneratedTitle;
		}

		public function set clipGeneratedTitle(value:String):void
		{
			_clipGeneratedTitle = value;
		}

		public function get clipGeneratedTitleWithoutExtension():String
		{
			return _clipGeneratedTitleWithoutExtension;
		}

		public function set clipGeneratedTitleWithoutExtension(value:String):void
		{
			_clipGeneratedTitleWithoutExtension = value;
		}

		public function get thumbsPath():String
		{
			return _thumbsPath;
		}

		public function set thumbsPath(value:String):void
		{
			_thumbsPath = value;
		}

		public function get swfPath():String
		{
			return _swfPath;
		}

		public function set swfPath(value:String):void
		{
			_swfPath = value;
		}


	}
}