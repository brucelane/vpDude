package com.riaspace.nativeUpdater
{
	import flash.desktop.NativeApplication;
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	
	import mx.controls.Alert;
	
	public class NativeUpdater
	{
		/**
		 * URL pointing to the file with the update descriptor.
		 * 
		 * In the ADC demo it only points to a local folder where application is installed.
		 * In case of real application it should point to a file on HTTP server.
		 */
		protected static const UPDATE_DESCRIPTOR_URL:String = "http://www.videopong.net/vpdudefiles/vpDude.xml";
		
		/**
		 * Downloaded update file
		 */
		protected var updateFile:File;
		
		/**
		 * FileStream used to write update file downloaded bytes.
		 */
		protected var fileStream:FileStream;
		
		/**
		 * URLStream used to download update file bytes.
		 */
		protected var urlStream:URLStream;
		
		/**
		 * Initiates update procedure. Update procedure will run if current application
		 * version is not equal to the remote version. This comparison is done based on
		 * the values from application descriptor and downloaded update descriptor.
		 */
		public function updateApplication():void
		{
			downloadUpdateDescriptor();
		}
		
		protected function downloadUpdateDescriptor():void
		{
			var updateDescLoader:URLLoader = new URLLoader;
			updateDescLoader.addEventListener(Event.COMPLETE, updateDescLoader_completeHandler);
			updateDescLoader.addEventListener(IOErrorEvent.IO_ERROR, updateDescLoader_ioErrorHandler);
			updateDescLoader.load(new URLRequest(UPDATE_DESCRIPTOR_URL));
		}
		
		protected function updateDescLoader_completeHandler(event:Event):void
		{
			var loader:URLLoader = URLLoader(event.currentTarget);
			
			// Closing update descriptor loader
			closeUpdateDescLoader(loader);
		
			// Getting update descriptor XML from loaded data
			var updateDescriptor:XML = XML(loader.data);
			// Getting default namespace of update descriptor
			var udns:Namespace = updateDescriptor.namespace();
			
			// Getting application descriptor XML
			var applicationDescriptor:XML = NativeApplication.nativeApplication.applicationDescriptor;
			// Getting default namespace of application descriptor
			var adns:Namespace = applicationDescriptor.namespace();
			
			// Getting versionNumber from update descriptor
			var updateVersion:String = updateDescriptor.udns::versionNumber.toString();
			// Getting versionNumber from application descriptor
			var currentVersion:String = applicationDescriptor.adns::versionNumber.toString();
			
			// Comparing current version with update version
			if (currentVersion != updateVersion)
			{
				// Getting update url
				var updateUrl:String = updateDescriptor.udns::url.toString();
				// Downloading update file
				downloadUpdate(updateUrl);
			}
		}
		
		protected function updateDescLoader_ioErrorHandler(event:IOErrorEvent):void
		{
			closeUpdateDescLoader(URLLoader(event.currentTarget));
			Alert.show("ERROR loading update descriptor:", event.text);
		}
		
		protected function closeUpdateDescLoader(loader:URLLoader):void
		{
			loader.removeEventListener(Event.COMPLETE, updateDescLoader_completeHandler);
			loader.removeEventListener(IOErrorEvent.IO_ERROR, updateDescLoader_ioErrorHandler);
			loader.close();
		}
		
		protected function downloadUpdate(updateUrl:String):void
		{
			// Parsing file name out of the download url
			var fileName:String = updateUrl.substr(updateUrl.lastIndexOf("/") + 1);
			
			// Creating new file ref in temp directory
			updateFile = File.createTempDirectory().resolvePath(fileName);

			// Using URLStream to download update file
			urlStream = new URLStream;
			urlStream.addEventListener(Event.OPEN, urlStream_openHandler);
			urlStream.addEventListener(ProgressEvent.PROGRESS, urlStream_progressHandler);
			urlStream.addEventListener(Event.COMPLETE, urlStream_completeHandler);
			urlStream.addEventListener(IOErrorEvent.IO_ERROR, urlStream_ioErrorHandler);
			urlStream.load(new URLRequest(updateUrl));
		}
		
		protected function urlStream_openHandler(event:Event):void
		{
			// Creating new FileStream to write downloaded bytes into
			fileStream = new FileStream;
			fileStream.open(updateFile, FileMode.WRITE);
		}
		
		protected function urlStream_progressHandler(event:ProgressEvent):void
		{
			// ByteArray with loaded bytes
			var loadedBytes:ByteArray = new ByteArray;
			// Reading loaded bytes
			urlStream.readBytes(loadedBytes);
			// Writing loaded bytes into the FileStream
			fileStream.writeBytes(loadedBytes);
		}
		
		protected function urlStream_completeHandler(event:Event):void
		{
			// Closing URLStream and FileStream
			closeStreams();
			
			// Installing update
			installUpdate();
		}
		
		protected function installUpdate():void
		{
			// Running the installer using NativeProcess API
			var info:NativeProcessStartupInfo = new NativeProcessStartupInfo;
			info.executable = updateFile;
			
			var process:NativeProcess = new NativeProcess;
			process.start(info);
			
			// Exit application for the installer to be able to proceed
			NativeApplication.nativeApplication.exit();
		}
		
		protected function urlStream_ioErrorHandler(event:IOErrorEvent):void
		{
			closeStreams();
			Alert.show("ERROR downloading update:", event.text);
		}
		
		protected function closeStreams():void
		{
			urlStream.removeEventListener(Event.OPEN, urlStream_openHandler);
			urlStream.removeEventListener(ProgressEvent.PROGRESS, urlStream_progressHandler);
			urlStream.removeEventListener(Event.COMPLETE, urlStream_completeHandler);
			urlStream.removeEventListener(IOErrorEvent.IO_ERROR, urlStream_ioErrorHandler);
			urlStream.close();
			
			// Checking if FileStream was instantiated
			if (fileStream)
				fileStream.close();
		}
	}
}