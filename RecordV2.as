package  {
	
	//Basic class
	import flash.display.Sprite;
	// Comunicate with javscript
	import flash.external.ExternalInterface;
	// This is the device part (cam and mic)
	import flash.media.Camera;
	import flash.media.Microphone;
	// Used to get acces to cam and mic
	import flash.system.SecurityPanel;
	import flash.system.Security;
	// required for the connexion 
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.events.NetStatusEvent;
	// utils
	import flash.utils.*;
	// codec
	import flash.media.H264VideoStreamSettings;
	import flash.media.H264Level;
	import flash.media.H264Profile;


	public class RecordV2 extends Sprite {
		// URL of the red5 server
		private static const red5Server:String = "rtmp://your-server-address";
		
		// Quality settings
		private static const audioQuality = 10;
		private static const videoBandwith = 90000;
		private static const videoQuality = 90;
		private static const bufferTime = 30;
		
		// fileName created on the server
		private var fileName = null;
		// Cam and Mic
		private var cam = null;
		private var mic = null;
		private var shouldStopRecord = false;
		// connexion and stream
		private var netCon = null;
		private var stream = null;
		private var h264Settings = null;
		
		public function startRecord(fileName)
		{ 
			if (this.cam == null)
			{
				//trace("FlashCamRecord.camBusy");
				ExternalInterface.call("FlashCamRecord.camBusy");
				this.initCamAndMic();
			}
			else if (this.mic == null)
			{
				//trace("FlashCamRecord.micBusy");
				ExternalInterface.call("FlashCamRecord.micBusy");
				this.initCamAndMic();
			}
			else if (this.cam.muted == false && this.mic.muted == false)
			{
				this.fileName = fileName;
				this.netCon = new NetConnection();
				this.netCon.addEventListener(NetStatusEvent.NET_STATUS, this.netConStatusHandler, false, 0, true);
				this.netCon.connect(red5Server);				
			}
			else
			{
				//trace("FlashCamRecord.accessDenied");
				ExternalInterface.call("FlashCamRecord.accessDenied");
				Security.showSettings(SecurityPanel.PRIVACY);
			}
		}
		
		public function unpublishAndDisconnect()
		{
			//trace("unpublishAndDisconnect");
			this.stream.publish(false);
			this.stream.close();
			setTimeout(this.closeConnection, 1000);
		}

		private function netStreamStatusHandler(event:NetStatusEvent)
		{
			//trace("netStreamStatusHandler: " + event.info.code);
			if (event.info.code == "NetStream.Buffer.Empty" && this.shouldStopRecord)
			{
				this.shouldStopRecord = false;
				this.unpublishAndDisconnect();
			}
		}
			
		private function netConStatusHandler(event:NetStatusEvent)
		{
			trace("netConStatusHandler: " + event.info.code);
			if (event.info.code == "NetConnection.Connect.Success")
			{
				this.stream = new NetStream(this.netCon);
				this.stream.bufferTime = bufferTime; 
				this.stream.attachCamera(this.cam);
				this.stream.attachAudio(this.mic);
				this.stream.addEventListener(NetStatusEvent.NET_STATUS, this.netStreamStatusHandler, false, 0, true);
				this.stream.videoStreamSettings = this.h264Settings;
				this.stream.publish(this.fileName, "record");
				//trace("FlashCamRecord.started");
				ExternalInterface.call("FlashCamRecord.started");
			}
			else if (event.info.code == "NetConnection.Connect.Closed") 
			{
				//trace("FlashCamRecord.stopped");
				ExternalInterface.call("FlashCamRecord.stopped");
			}
			else
			{
				//trace("FlashCamRecord.connexionProblem");
				ExternalInterface.call("FlashCamRecord.connexionProblem");
			}
		}
		
		public function stopRecord()
		{
			// do we have info in buffer?
			if (this.stream.bufferLength > 0)
			{
				this.stream.attachCamera(null);
				this.stream.attachAudio(null);
				this.shouldStopRecord = true;
			}
			else
			{
				this.unpublishAndDisconnect();
			}
			//trace("stopRecord: " + this.stream.bufferLength);
		}
		
		private function closeConnection()
		{
			this.netCon.close();
		}
	
		private function initCamAndMic(){	
			// Mic part
			this.mic = Microphone.getEnhancedMicrophone();
			if (this.mic != null)
			{
				this.mic.codec = "Speex";
				this.mic.encodeQuality = audioQuality;
				this.mic.enableVAD = false;
			}
			else{
				//trace("FlashCamRecord.micBusy");
				ExternalInterface.call("FlashCamRecord.micBusy");
			}
			
			// we get the cameramicr
			this.cam = Camera.getCamera();
			if (this.cam != null)
			{
				// set cam parameters
				this.cam.setLoopback(true);
				this.cam.setMode(858, 480, 30, true);
				this.cam.setQuality(videoBandwith, audioQuality);
				this.cam.setKeyFrameInterval(15);

				// attach  cam to the video
				cam_video.attachCamera(this.cam);
			}
			else{
				//trace("FlashCamRecord.camBusy");
				ExternalInterface.call("FlashCamRecord.camBusy");
			}
			
			/*if (this.cam.muted || this.mic.muted)
			{
				Security.showSettings(SecurityPanel.PRIVACY);
			}*/
			// encode in h264
			this.h264Settings = new H264VideoStreamSettings();
			this.h264Settings.setProfileLevel( H264Profile.BASELINE, H264Level.LEVEL_3_1 )
		}
		
		public function RecordV2() {
			this.initCamAndMic();
			//this.startRecord("test_60");
			//setTimeout(stopRecord, 12000);
			ExternalInterface.addCallback("flashCamRecordStart", this.startRecord);  
			ExternalInterface.addCallback("FlashCamRecordStop", this.stopRecord);  
			ExternalInterface.call("FlashCamRecord.showRecordButton");
		}
	}
	
}
