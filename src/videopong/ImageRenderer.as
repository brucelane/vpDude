package videopong
{
	import flash.display.Bitmap;    
	import mx.containers.HBox;
	import mx.controls.Image;
	
	public class ImageRenderer extends HBox
	{
		private var img:Image = new Image();
		private var myBitmap:Bitmap;
		
		public function ImageRenderer(){
			// Set some layout properties
			this.setStyle("verticalAlign", "middle");
			this.setStyle("horizontalAlign", "center");
		}
		
		override public function set data(value:Object):void
		{
			super.data = value;
			// Create new Bitmap with the BitmapData from File.icon.bitmaps array
			// The first item in the Array is the biggest icon available
			myBitmap = new Bitmap( data.icon.bitmaps[0] );
			// Set the image source to the new Bitmap
			img.source = myBitmap;
			// Add the Image to the HBox
			addChild(img);
		}
	}
}