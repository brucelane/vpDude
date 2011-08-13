package fr.batchass
{
	import flash.filesystem.*;
	
	/**
	 * 	Simple utility to write a text file synchronously
	 */
	public function writeTextFile(file:File, contents:String):void {
		
		// create connection
		const stream:FileStream = new FileStream();
		stream.open(file, FileMode.WRITE);
		
		// write
		stream.writeUTFBytes(contents);
		
		// close the file
		stream.close();
		
	}
	
}