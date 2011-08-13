package videopong
{
	import components.Search;
	
	import flash.filesystem.File;
	
	import fr.batchass.*;
	
	import mx.collections.ArrayCollection;
	import mx.collections.XMLListCollection;

	public class Clips
	{
		private static var instance:Clips = new Clips();
		public var CLIPS_XML:XML = <videos /> ;
		// Collection of all the clips
		[Bindable]
		public var clipsXMLList:XMLListCollection = new XMLListCollection(CLIPS_XML.video);
		private static var _dbPath:String;		
		private static var clipsXmlPath:String;
		private var _acFilter:ArrayCollection;
		
		public function Clips()
		{
			if ( instance == null ) 
			{
				trace( "Clips first instance." );
			}
			else trace( "Clips already instanciated." );
		}
		
		public static function getInstance():Clips 
		{
			return instance;
		}
		public function loadClipsFile():void 
		{
			clipsXmlPath = _dbPath + File.separator + "clips.xml";
			var isConfigured:Boolean = false;
			var clipsFile:File = File.applicationStorageDirectory.resolvePath( clipsXmlPath );
			try
			{
				if ( !clipsFile.exists )
				{
					Util.log( "clips.xml does not exist" );
				}
				else
				{
					Util.log( "clips.xml exists, load the file xml" );
					CLIPS_XML = new XML( readTextFile( clipsFile ) );
					if ( CLIPS_XML..video.length() )
					{
						isConfigured = true;
						//loadFilesInCache();
					}
				}
			}
			catch ( e:Error )
			{	
				Util.log( 'Error loading clips.xml file: ' + e.message );
			}
			if ( !isConfigured )
			{
				CLIPS_XML = <videos />;
				writeClipsFile(true);
			}
			refreshClipsXMLList();
		}
		/*public function loadFilesInCache():void 
		{
			trace("loadFilesInCache");				
			
		}*/
		public function writeClipsFile(refreshDatabind:Boolean):void 
		{
			clipsXmlPath = _dbPath + File.separator + "clips.xml";
			var clipsFile:File = File.applicationStorageDirectory.resolvePath( clipsXmlPath );
			
			// write the text file
			writeTextFile( clipsFile, CLIPS_XML );					
			if (refreshDatabind) refreshClipsXMLList();
		}
		// refresh XML collection for data binding
		public function refreshClipsXMLList():void 
		{
			clipsXMLList = new XMLListCollection( CLIPS_XML.video );
		}
		// write one clip xml file in db
		public function writeClipXmlFile( clipId:String, clipXml:XML ):void
		{
			var localClipXMLFile:String = _dbPath + File.separator + clipId + ".xml" ;
			var clipXmlFile:File = new File( localClipXMLFile );
			
			// write the text file
			writeTextFile( clipXmlFile, clipXml );					
		}
		// test if new tag in clip xml
		public function addTagIfNew( tag:String, clipId:String, refreshDatabind:Boolean ):void
		{
			//read clip xml file
			var localClipXMLFile:String = _dbPath + File.separator + clipId + ".xml" ;
			var clipXmlFile:File = new File( localClipXMLFile );
			
			var clipXml:XML = new XML( readTextFile( clipXmlFile ) );;					
			//test if tag in clip xml
			var clipTagList:XMLList = clipXml..tag as XMLList;
			var foundNewTag:Boolean = true;
			for each ( var clipTag:XML in clipTagList )
			{
				if ( clipTag.@name == tag )
				{
					foundNewTag = false;
				}
			}
			if ( foundNewTag )
			{		
				trace( tag + " is new tag, save in clip xml file");
				// to lower case
				tag = tag.toLowerCase();
				var newTag:XML = <tag name={tag} creationdate={Util.nowDate}  />;
				clipXml..tags.appendChild( newTag );
				writeClipXmlFile( clipId, clipXml );
				//update global CLIPS_XML file
				CLIPS_XML..video.(@id==clipId).tags.appendChild( newTag );
				writeClipsFile( refreshDatabind );
				/*reset refreshClipsXMLList();*/
				var tags:Tags = Tags.getInstance();
				tags.addTagIfNew( tag );
			}
			else
			{
				trace( tag + " already in clip xml file");
			}
			
		}
		// remove all tags in clip xml and add originally added tags
		public function removeTags( clipId:String ):void
		{
			//read clip xml file
			var localClipXMLFile:String = _dbPath + File.separator + clipId + ".xml" ;
			var clipXmlFile:File = new File( localClipXMLFile );
			
			var clipXml:XML = new XML( readTextFile( clipXmlFile ) );;					
			
			delete clipXml.tags.tag;
			//remove tags from global CLIPS_XML file
			delete CLIPS_XML..video.(@id==clipId).tags.tag;

			//test for addedtag in clip xml
			var clipTagList:XMLList = clipXml..addedtag as XMLList;
			for each ( var clipTag:XML in clipTagList )
			{
				var clipOriginalXmlTag:XML = <tag name={clipTag.@name} creationdate={Util.nowDate}  />;
				clipXml.tags.appendChild( clipOriginalXmlTag );	
				CLIPS_XML..video.(@id==clipId).tags.appendChild( clipOriginalXmlTag );	
			}
			
			writeClipXmlFile( clipId, clipXml );
			writeClipsFile(false);
			//refreshClipsXMLList();
		}
		public function newClip( urllocal:String ):Boolean
		{
			var foundNewClip:Boolean = true;
			if ( urllocal )
			{
				for each ( var appClip:XML in clipsXMLList )
				{
					if ( appClip.@urllocal.toString() == urllocal )
					{
						foundNewClip = false;
					}
				}
				
			}
			return foundNewClip;
		}
		public function fileChanged( urllocal:String, ownFolderPath:String ):Boolean
		{
			var hasChanged:Boolean = false;
			if ( urllocal )
			{
				for each ( var appClip:XML in clipsXMLList )
				{
					if ( appClip.@urllocal.toString() == urllocal )
					{
						// clip is found TODO check modification date
						var xmlModDate:String = appClip.@datemodified.toString();
						Util.log( urllocal + " date in XML: " + xmlModDate  );
						
						//path to original own video
						var clipPath:String = ownFolderPath + File.separator + urllocal;
						var clipFile:File = File.applicationStorageDirectory.resolvePath( clipPath );
						try
						{
							if ( !clipFile.exists )
							{
								// what to do? hasChanged = true; ?
								Util.log( clipPath + " does not exist" );
							}
							else
							{
								Util.log( clipPath + " exists, compare modification date" );
								var clipModificationDate:String = clipFile.modificationDate.toUTCString();
								Util.log( urllocal + " date in file system: " + clipModificationDate  );
								if ( clipModificationDate == xmlModDate )
								{
									//same date
									Util.log( "same date" );
								}
								else
								{
									//different date
									Util.log( "different date" );
									hasChanged = true;
								}
							}
						}
						catch ( e:Error )
						{	
							hasChanged = true;
							Util.log( "Error loading " + clipPath + " file: " + e.message );
						}
					}
				}				
			}
			return hasChanged;
		}
		public function clipIsNew( clipGeneratedName:String, urllocal:String=null ):Boolean
		{
			var foundNewClip:Boolean = true;
			if ( urllocal )
			{
				// for own clips, test if already in db
				foundNewClip = newClip( urllocal );
			}
			else
			{
				// for downloaded clips, test if already in db
				for each ( var appClip:XML in clipsXMLList )
				{
					if ( appClip.@id.toString() == clipGeneratedName )
					{
						foundNewClip = false;
					}
				}
				
			}
			return foundNewClip;
		}
		public function addNewClip( clipGeneratedName:String, clipXml:XML, urllocal:String=null ):void
		{
			var foundNewClip:Boolean = true;
			if ( urllocal )
			{
				// for own clips, test if already in db
				foundNewClip = newClip( urllocal );
			}
			else
			{
				// for downloaded clips, test if already in db
				for each ( var appClip:XML in clipsXMLList )
				{
					if ( appClip.@id.toString() == clipGeneratedName )
					{
						foundNewClip = false;
					}
				}
				
			}
			if ( foundNewClip )
			{
				CLIPS_XML.appendChild( clipXml );
				writeClipsFile(true);	
				writeClipXmlFile( clipGeneratedName, clipXml );
			}
		}
		public function deleteClip( clipGeneratedName:String, urllocal:String=null ):void
		{		
			delete CLIPS_XML..video.(@id==clipGeneratedName)[0];
			writeClipsFile(true);	
		}
		
		public function filterTags( acFilter:ArrayCollection ):void 
		{
			_acFilter = acFilter;
			if ( acFilter.length == 0 ) 
			{
				clipsXMLList.filterFunction = null;
			} 
			else 
			{
				clipsXMLList.filterFunction = xmlListColl_filterFunc;
			}
			clipsXMLList.refresh();
		}
		
		private function xmlListColl_filterFunc(item:Object):Boolean 
		{
			var isMatch:Boolean = false;
			var currentTag:String;
			var nbFound:uint = 0;
			var clipTags:String = "";// = item..@name;
			
			// search for tag name attribute
			for each ( var oneTag:XML in item..tag )
			{
				clipTags += oneTag.@name.toString().toLowerCase() + "|";
			}
			// search for creator name attribute
			clipTags += item..creator.@name.toString().toLowerCase() + "|";
			// search for clip name attribute
			clipTags += item..clip.@name.toString().toLowerCase() + "|";
			
			for each ( currentTag in _acFilter ) 
			{
				trace( "cur:" + currentTag );
				if ( clipTags.indexOf( currentTag ) > -1 ) nbFound++;
			}
			if ( nbFound >= _acFilter.length ) isMatch = true;
			return isMatch;
		}

		public function get dbPath():String
		{
			return _dbPath;
		}
		
		public function set dbPath(value:String):void
		{
			_dbPath = value;
		}

	}
}
