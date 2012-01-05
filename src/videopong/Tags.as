package videopong
{
	import flash.filesystem.File;
	
	import fr.batchass.*;
	
	import mx.collections.XMLListCollection;
	
	public class Tags
	{
		private static var instance:Tags = new Tags();
		private static var tagsXmlPath:String;
		public var TAGS_XML:XML = <tags>
									<tag name="own"/>
								  </tags>;
		// Collection of tags
		[Bindable]
		public var tagsXMLList:XMLListCollection = new XMLListCollection(TAGS_XML.tag.@name);
		
		private var session:Session = Session.getInstance();
		
		public function Tags( )
		{
			if ( instance == null ) 
			{
				
			}
			else trace( "Tags already instanciated." );
		}
		
		public static function getInstance():Tags 
		{
			return instance;
		}		
		
		public function loadTagsFile():void 
		{
			tagsXmlPath = session.dbFolderPath + File.separator + "tags.xml";
			var isConfigured:Boolean = false;
			var tagsFile:File = File.applicationStorageDirectory.resolvePath( tagsXmlPath );
			try
			{
				if ( !tagsFile.exists )
				{
					Util.log( "tags.xml does not exist" );
				}
				else
				{
					Util.log( "tags.xml exists, load the file xml" );
					TAGS_XML = new XML( readTextFile( tagsFile ) );
					if ( TAGS_XML..tag.length() )
					{
						isConfigured = true;
					}
				}
			}
			catch ( e:Error )
			{	
				var msg:String = 'Error loading tags.xml file: ' + e.message;
				Util.log( msg );
			}
			if ( !isConfigured )
			{
				writeTagsFile();
			}
			refreshTagsXMLList();
		}
		public function writeTagsFile():void 
		{
			tagsXmlPath = session.dbFolderPath + File.separator + "tags.xml";
			var tagsFile:File = File.applicationStorageDirectory.resolvePath( tagsXmlPath );
			// sort the TAGS_XML
			var arrayToSort:Array = new Array();
			for each ( var item:XML in TAGS_XML.tag )
			{
				arrayToSort.push( {name:item.@name,creationdate:item.@creationdate} );
			}
			
			arrayToSort.sortOn( "name" );
			TAGS_XML =  <tags>
						</tags>;
			for each ( var arrayItem in arrayToSort )
			{
				TAGS_XML.appendChild( <tag name={arrayItem.name} creationdate={arrayItem.creationdate} /> );
			}					
			// write the text file
			writeTextFile( tagsFile, TAGS_XML );					
			refreshTagsXMLList();
		}
		//refresh XML collection for data binding
		public function refreshTagsXMLList():void 
		{
			tagsXMLList = new XMLListCollection( TAGS_XML.tag.@name );
		}
		
		public function addTagIfNew( tagToSearch:String ):void
		{
			tagToSearch = tagToSearch.toLowerCase();
			trace( TAGS_XML..tag.(@name==tagToSearch).length() );
			if ( TAGS_XML..tag.(@name==tagToSearch).length() < 1 )
			{
				TAGS_XML.appendChild( <tag name={tagToSearch} creationdate={Util.nowDate} /> );
				writeTagsFile();
			}
			
		}
		public function resyncTags():void
		{	
			Util.log( "resyncTags start");
			TAGS_XML =  <tags>
							<tag name="own"/>
						</tags>;
			
			//check for tags in clip xml
			var clips:Clips = Clips.getInstance();
			var clipTagList:XMLList = clips.CLIPS_XML..tag as XMLList;
			for each ( var clipTag:XML in clipTagList )
			{
				addTagIfNew( clipTag.@name );
			}			
			
			refreshTagsXMLList();
			Util.log( "resyncTags end");
		}
	}
}