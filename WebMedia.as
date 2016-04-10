package {
    import flash.external.ExternalInterface;
    import flash.display.Sprite;
    import flash.system.Security;
    import flash.utils.Timer;
    import flash.media.*;
    import flash.net.*;
    import flash.events.*;

    public class WebMedia extends Sprite {
        [Bindable] private var nc:NetConnection;
        [Bindable] private var ns:NetStream;
        private var serverUrl:String;
        private var video:Video;
        private var cam:Camera;
        private var mic:Microphone;
        private var camStatus:String = 'None';
        private var movName:String;
        private var videoWidth:int;
        private var videoHeight:int;

        public function WebMedia() {
            Security.allowDomain('*');
            ExternalInterface.call('console.log', 'available ' + ExternalInterface.available);

            serverUrl = ExternalInterface.call('getServer');

            debug('server ' + serverUrl);
            debug('Added');

            videoWidth = ExternalInterface.call('getWidth');
            videoHeight = ExternalInterface.call('getHeight');

            rtmpConnect(serverUrl);
            startPoll();
            initVideo(videoWidth, videoHeight);
            initCamera();
            initMic();
            video.attachCamera(cam);
            addChild(video);
        }

        private function startPoll():void {
            var statusTimer:Timer = new Timer(330, 0);
            statusTimer.addEventListener(TimerEvent.TIMER, pollStatus);
            statusTimer.start();
        }

        private function rtmpConnect(url:String):void {
            NetConnection.defaultObjectEncoding = ObjectEncoding.AMF0; // MUST SUPPLY THIS!!!

            if (nc == null) {
                nc = new NetConnection();
                nc.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler, false, 0, true);
                nc.addEventListener(IOErrorEvent.IO_ERROR, errorHandler, false, 0, true);
                nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler, false, 0, true);
                nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR, errorHandler, false, 0, true);
                nc.client = {};

                debug('connect() ' + url);
                nc.connect(url);
            }
        }

        private function close():void {
            debug('close()');
            if (nc != null) {
                nc.close();
                nc = null;
            }
        }

        private function publish(name:String, record:Boolean):void {
            if (ns != null && nc != null && nc.connected) {
                debug('in publish ' + name + ' ' + record);
                ns.publish(name, record ? 'record' : null);
                debug('Publishing ' + name);
            }
        }

        private function closeStream(current:Video):void {
            if (ns != null) {
                ns.close();
                ns = null;
            }
            video.clear();
            removeChild(current);
        }

        private function netStatusHandler(event:NetStatusEvent):void {
            debug('netStatusHandler() ' + event.type + ' ' + event.info.code);
            switch (event.info.code) {
            case 'NetConnection.Connect.Success':
                debug('connected ' + nc.connected);

                ExternalInterface.call('serverConnected');
                break;
            case 'NetConnection.Connect.Failed':
            case 'NetConnection.Connect.Reject':
            case 'NetConnection.Connect.Closed':
                ExternalInterface.call('serverDisconnected');
                nc = null;
                break;
            case 'NetStream.Play.Stop':
                ExternalInterface.call('playbackEnded');
                closeStream(video);
                break;
            }
        }

        private function errorHandler(event:ErrorEvent):void {
            debug('errorHandler() ' + event.type + ' ' + event.text);
            if (nc != null)
                nc.close();
            nc = null;
        }

        private function streamErrorHandler(event:ErrorEvent):void {
            debug('streamErrorHandler() ' + event.type + ' ' + event.text);
        }

        private function debug(msg:String):void {
            ExternalInterface.call('console.log', msg);
        }

        private function initCamera():void {
            debug('initCamera()');
            debug('updated');
            cam = Camera.getCamera();
            cam.setMode(1024, 768, 30, false);
            cam.setQuality(0, 100);
            cam.setKeyFrameInterval(2);

            debug('width: ' + cam.width);
            debug('height: ' + cam.height);
            debug('camera: ' + cam.name);
            debug('status: ' + camStatus);
        }

        private function initRecord():void {
            debug('initRecord()');

            ns = new NetStream(nc);
            ns.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler, false, 0, true);
            ns.addEventListener(IOErrorEvent.IO_ERROR, streamErrorHandler, false, 0, true);
            ns.addEventListener(AsyncErrorEvent.ASYNC_ERROR, streamErrorHandler, false, 0, true);

            ns.attachCamera(cam);
            ns.attachAudio(mic);

            ExternalInterface.addCallback('initFlash', initVideo);
            ExternalInterface.addCallback('serverConnect', rtmpConnect);
            ExternalInterface.addCallback('startRecording', publish);
        }

        private function initMic():void {
            mic = Microphone.getMicrophone();
            mic.rate = 22;
        }

        private function initVideo(w:int, h:int):void {
            debug('initVideo()');
            video = new Video();
            video.smoothing = true;
            video.scaleX = video.scaleY = 1.6;
        }

        private function pollStatus(event:TimerEvent):void {
            var newStatus:String = ExternalInterface.call('getStatus');
            if (newStatus != camStatus) {
                debug('status changed to: ' + newStatus);
                camStatus = newStatus;
                if (newStatus == 'recording') {
                    debug('calling initRecord()');
                    initRecord();
                    movName = ExternalInterface.call('movieName');
                    publish(movName, true);
                }
                else if (newStatus == 'stop') {
                    closeStream(video);
                }
            }
        }
    }
}
