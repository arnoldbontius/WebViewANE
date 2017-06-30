/*
 * Copyright 2017 Tua Rua Ltd.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 *  Additional Terms
 *  No part, or derivative of this Air Native Extensions's code is permitted
 *  to be sold as the basis of a commercially packaged Air Native Extension which
 *  undertakes the same purpose as this software. That is, a WebView for Windows,
 *  OSX and/or iOS and/or Android.
 *  All Rights Reserved. Tua Rua Ltd.
 */

package com.tuarua {
import com.tuarua.fre.ANEContext;
import com.tuarua.utils.GUID;
import com.tuarua.webview.ActionscriptCallback;
import com.tuarua.webview.BackForwardList;
import com.tuarua.webview.DownloadProgress;
import com.tuarua.webview.JavascriptResult;
import com.tuarua.webview.Settings;
import com.tuarua.webview.TabDetails;
import com.tuarua.webview.WebViewEvent;

import flash.display.BitmapData;
import flash.display.Stage;

import flash.events.EventDispatcher;
import flash.events.FullScreenEvent;
import flash.events.StatusEvent;
import flash.external.ExtensionContext;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.utils.Dictionary;

public class WebViewANE extends EventDispatcher {
    private static const name:String = "WebViewANE";
    private var _isInited:Boolean = false;
    private var _isSupported:Boolean = false;
    private var _viewPort:Rectangle;
    private var _url:String;
    private var _title:String;
    private var _isLoading:Boolean;
    private var _canGoBack:Boolean;
    private var _canGoForward:Boolean;
    private var _estimatedProgress:Number;
    private var _statusMessage:String;
    private var asCallBacks:Dictionary = new Dictionary(); // as -> js -> as
    private var jsCallBacks:Dictionary = new Dictionary(); //js - > as -> js
    private static const AS_CALLBACK_PREFIX:String = "TRWV.as.";
    private static const JS_CALLBACK_PREFIX:String = "TRWV.js.";
    private static const JS_CALLBACK_EVENT:String = "TRWV.js.CALLBACK";
    private static const AS_CALLBACK_EVENT:String = "TRWV.as.CALLBACK";
    private var downloadProgress:DownloadProgress = new DownloadProgress();
    private var _visible:Boolean;
    private var _backgroundColor:uint = 0xFFFFFF;
    private var _backgroundAlpha:Number = 1.0;
    private var _stage:Stage;

    public function WebViewANE() {
        initiate();
    }

    /**
     * This method is omitted from the output. * * @private
     */
    protected function initiate():void {
        _isSupported = true;

        if (_isSupported) {
            trace("[" + name + "] Initalizing ANE...");
            try {
                ANEContext.ctx = ExtensionContext.createExtensionContext("com.tuarua." + name, null);
                ANEContext.ctx.addEventListener(StatusEvent.STATUS, gotEvent);
                _isSupported = ANEContext.ctx.call("isSupported");
            } catch (e:Error) {
                trace("[" + name + "] ANE Not loaded properly.  Future calls will fail.");
            }
        } else {
            trace("[" + name + "] Can't initialize.");
        }

    }

    /**
     * This method is omitted from the output. * * @private
     */
    private function gotEvent(event:StatusEvent):void {
        //trace("gotEvent", event);
        var keyName:String;
        var argsAsJSON:Object;
        var pObj:Object;
        switch (event.level) {
            case "TRACE":
                trace(event.code);
                break;

            case WebViewEvent.ON_PROPERTY_CHANGE:
                pObj = JSON.parse(event.code);

                var tab:int = 0;
                if (pObj.hasOwnProperty("tab")) {
                    tab = pObj.tab;
                }

                if (currentTab == tab) {
                    if (pObj.propName == "url") {
                        _url = pObj.value;
                    } else if (pObj.propName == "title") {
                        _title = pObj.value;
                    } else if (pObj.propName == "isLoading") {
                        _isLoading = pObj.value;
                    } else if (pObj.propName == "canGoBack") {
                        _canGoBack = pObj.value;
                    } else if (pObj.propName == "canGoForward") {
                        _canGoForward = pObj.value;
                    } else if (pObj.propName == "estimatedProgress") {
                        _estimatedProgress = pObj.value;
                    } else if (pObj.propName == "statusMessage") {
                        _statusMessage = pObj.value;
                    }
                }
                //trace(event.code);


                dispatchEvent(new WebViewEvent(WebViewEvent.ON_PROPERTY_CHANGE, {
                    propertyName: pObj.propName,
                    value: pObj.value,
                    tab: tab
                }));
                break;
            case WebViewEvent.ON_FAIL:
                dispatchEvent(new WebViewEvent(WebViewEvent.ON_FAIL, (event.code.length > 0)
                        ? JSON.parse(event.code) : null));
                break;

            case JS_CALLBACK_EVENT: //js->as->js
                try {
                    argsAsJSON = JSON.parse(event.code);
                    for (var key:Object in jsCallBacks) {
                        var asCallback:ActionscriptCallback = new ActionscriptCallback();
                        keyName = key as String;
                        if (keyName == argsAsJSON.functionName) {
                            var tmpFunction1:Function = jsCallBacks[key] as Function;
                            asCallback.functionName = argsAsJSON.functionName;
                            asCallback.callbackName = argsAsJSON.callbackName;
                            asCallback.args = argsAsJSON.args;
                            tmpFunction1.call(null, asCallback);
                            break;
                        }
                    }

                } catch (e:Error) {
                    trace(e.message);
                    break;
                }

                break;
            case AS_CALLBACK_EVENT:

                try {
                    argsAsJSON = JSON.parse(event.code);
                } catch (e:Error) {
                    trace(e.message);
                    break;
                }
                for (var keyAs:Object in asCallBacks) {
                    keyName = keyAs as String;

                    if (keyName == argsAsJSON.callbackName) {
                        var jsResult:JavascriptResult = new JavascriptResult();
                        jsResult.error = argsAsJSON.error;
                        jsResult.message = argsAsJSON.message;
                        jsResult.success = argsAsJSON.success;
                        jsResult.result = argsAsJSON.result;
                        var tmpFunction2:Function = asCallBacks[keyAs] as Function;
                        tmpFunction2.call(null, jsResult);
                    }
                }
                break;
            case WebViewEvent.ON_DOWNLOAD_PROGRESS:
                try {
                    pObj = JSON.parse(event.code);
                    downloadProgress.bytesLoaded = pObj.bytesLoaded;
                    downloadProgress.bytesTotal = pObj.bytesTotal;
                    downloadProgress.percent = pObj.percent;
                    downloadProgress.speed = pObj.speed;
                    downloadProgress.id = pObj.id;
                    downloadProgress.url = pObj.url;
                    dispatchEvent(new WebViewEvent(WebViewEvent.ON_DOWNLOAD_PROGRESS, downloadProgress));
                } catch (e:Error) {
                    trace(e.message);
                    break;
                }
                break;
            case WebViewEvent.ON_DOWNLOAD_COMPLETE:
                dispatchEvent(new WebViewEvent(WebViewEvent.ON_DOWNLOAD_COMPLETE, event.code));
                break;
            case WebViewEvent.ON_DOWNLOAD_CANCEL:
                dispatchEvent(new WebViewEvent(WebViewEvent.ON_DOWNLOAD_CANCEL, event.code));
                break;
            case WebViewEvent.ON_ESC_KEY:
                dispatchEvent(new WebViewEvent(WebViewEvent.ON_ESC_KEY, event.code));
                break;
            case WebViewEvent.ON_URL_BLOCKED:
                try {
                    argsAsJSON = JSON.parse(event.code);
                } catch (e:Error) {
                    trace(e.message);
                    break;
                }
                dispatchEvent(new WebViewEvent(WebViewEvent.ON_URL_BLOCKED, argsAsJSON));
                break;
            case WebViewEvent.ON_PERMISSION_RESULT:
                try {
                    pObj = JSON.parse(event.code);
                    var permission:Object = {};
                    permission.result = pObj.result;
                    permission.type = pObj.type;
                    dispatchEvent(new WebViewEvent(WebViewEvent.ON_PERMISSION_RESULT, permission));
                } catch (e:Error) {
                    trace(e.message);
                    break;
                }
                break;

            default:
                break;
        }
    }

    /**
     *
     * @param functionName name of the function as called from Javascript
     * @param closure Actionscript function to call when functionName is called from Javascript
     *
     * <p>Adds a callback in the webView. These should be added before .init() is called.</p>
     *
     */
    public function addCallback(functionName:String, closure:Function):void {
        jsCallBacks[functionName] = closure;
    }

    /**
     *
     * @param functionName name of the function to remove. This function should have been added via .addCallback() method
     *
     */
    public function removeCallback(functionName:String):void {
        jsCallBacks[functionName] = null;
    }


    /**
     *
     * @param functionName name of the Javascript function to call
     * @param closure Actionscript function to call when Javascript functionName is called. If null then no
     * actionscript function is called, aka a 'fire and forget' call.
     * @param args arguments to send to the Javascript function
     *
     * <p>Call a javascript function.</p>
     *
     * @example
     <listing version="3.0">
     // Logs to the console. No result expected.
     webView.callJavascriptFunction("as_to_js",asToJsCallback,1,"a",77);

     public function asToJsCallback(jsResult:JavascriptResult):void {
    trace("asToJsCallback");
    trace("jsResult.error", jsResult.error);
    trace("jsResult.result", jsResult.result);
    trace("jsResult.message", jsResult.message);
    trace("jsResult.success", jsResult.success);
    var testObject:* = jsResult.result;
    trace(testObject);
}
     }
     </listing>

     * @example
     <listing version="3.0">
     // Calls Javascript function passing 3 args. Javascript function returns an object which is automatically mapped to an
     Actionscript Object
     webView.callJavascriptFunction("console.log",null,"hello console. The is AIR");
     }

     // function in HTML page
     function as_to_js(numberA, stringA, numberB, obj) {
    var person = {
        name: "Jim Cowart",
        response: {
            name: "Chattanooga",
            population: 167674
        }
    };
    return person;
}
     </listing>
     */
    public function callJavascriptFunction(functionName:String, closure:Function = null, ...args):void {
        if (safetyCheck()) {
            var finalArray:Array = [];
            for each (var arg:* in args)
                finalArray.push(JSON.stringify(arg));
            var js:String = functionName + "(" + finalArray.toString() + ");";
            if (closure != null) {
                asCallBacks[AS_CALLBACK_PREFIX + functionName] = closure;
                ANEContext.ctx.call("callJavascriptFunction", js, AS_CALLBACK_PREFIX + functionName);
            } else {
                ANEContext.ctx.call("callJavascriptFunction", js, null);
            }
        }
    }

    //to insert script or run some js, no closure fire and forget
    /**
     *
     * @param code Javascript string to evaluate.
     * @param closure Actionscript function to call when the Javascript string is evaluated. If null then no
     * actionscript function is called, aka a 'fire and forget' call.
     *
     * @example
     <listing version="3.0">
     // Set the body background to yellow. No result expected
     webView.evaluateJavascript('document.getElementsByTagName("body")[0].style.backgroundColor = "yellow";');
     </listing>
     * @example
     <listing version="3.0">
     // Retrieve contents of div. Result is returned to Actionscript function 'onJsEvaluated'
     webView.evaluateJavascript("document.getElementById('output').innerHTML;", onJsEvaluated)
     private function onJsEvaluated(jsResult:JavascriptResult):void {
    trace("innerHTML of div is:", jsResult.result);
}
     </listing>
     *
     */
    public function evaluateJavascript(code:String, closure:Function = null):void {
        if (safetyCheck()) {
            if (closure != null) {
                var guid:String = GUID.create();
                asCallBacks[AS_CALLBACK_PREFIX + guid] = closure;
                ANEContext.ctx.call("evaluateJavaScript", code, AS_CALLBACK_PREFIX + guid);
            } else {
                ANEContext.ctx.call("evaluateJavaScript", code, null);
            }
        }
    }

    /**
     *
     * @param stage
     * @param viewPort
     * @param initialUrl Url to load when the view loads
     * @param settings
     * @param scaleFactor iOS and Android only
     * @param backgroundColor value of the view's background color.
     * @param backgroundAlpha set to 0.0 for transparent background. iOS and Android only
     *
     * <p>Initialises the webView. N.B. The webView is set to visible = false initially.</p>
     *
     */
    public function init(stage:Stage, viewPort:Rectangle, initialUrl:String = null,
                         settings:Settings = null, scaleFactor:Number = 1.0,
                         backgroundColor:uint = 0xFFFFFF, backgroundAlpha:Number = 1.0):void {
        _stage = stage;
        //stage.addEventListener(FullScreenEvent.FULL_SCREEN, onFullScreenEvent);
        _viewPort = viewPort;

        //hasn't been set by setBackgroundColor
        if (_backgroundColor == 0xFFFFFF) {
            _backgroundColor = backgroundColor;
        }
        if (_backgroundAlpha == 1.0) {
            _backgroundAlpha = backgroundAlpha;
        }

        if (_isSupported) {
            var _settings:Settings = settings;
            if (_settings == null) {
                _settings = new Settings();
            }

            ANEContext.ctx.call("init", initialUrl, _viewPort, _settings, scaleFactor, _backgroundColor,
                    _backgroundAlpha);
            _isInited = true;
        }
    }

    private function onFullScreenEvent(event:FullScreenEvent):void {
        //if (safetyCheck()) {
        //ANEContext.ctx.call("onFullScreen", event.fullScreen);
        //}
    }

    [Deprecated(replacement="viewPort")]
    public function setPositionAndSize(x:int = 0, y:int = 0, width:int = 0, height:int = 0):void {
        _viewPort = new Rectangle(x, y, width, height);
        if (safetyCheck()) {
            ANEContext.ctx.call("setPositionAndSize", _viewPort);
        }
    }

    [Deprecated(replacement="visible")]
    public function addToStage():void {
        if (safetyCheck())
            ANEContext.ctx.call("addToStage");
    }

    [Deprecated(replacement="visible")]
    public function removeFromStage():void {
        if (safetyCheck())
            ANEContext.ctx.call("removeFromStage");
    }


    /**
     *
     * @param url
     *
     */
    public function load(url:String):void {
        if (safetyCheck()) {
            ANEContext.ctx.call("load", url);
        }

    }

    /**
     *
     * @param html HTML provided as a string
     * @param baseUrl url which will display as the address
     *
     * <p>Loads a HTML string into the webView.</p>
     *
     */
    public function loadHTMLString(html:String, baseUrl:String = ""):void {
        if (safetyCheck())
            ANEContext.ctx.call("loadHTMLString", html, baseUrl);
    }

    /**
     *
     * @param url full path to the file on the local file system
     * @param allowingReadAccessTo path to the root of the document
     *
     * <p>Loads a file from the local file system into the webView.</p>
     *
     */
    public function loadFileURL(url:String, allowingReadAccessTo:String):void {
        if (safetyCheck())
            ANEContext.ctx.call("loadFileURL", url, allowingReadAccessTo);
    }

    /**
     * <p>Reloads the current page.</p>
     */
    public function reload():void {
        if (safetyCheck())
            ANEContext.ctx.call("reload");
    }

    /**
     * <p>Stops loading the current page.</p>
     */
    public function stopLoading():void {
        if (safetyCheck())
            ANEContext.ctx.call("stopLoading");
    }

    /**
     * <p>Navigates back.</p>
     */
    public function goBack():void {
        if (safetyCheck())
            ANEContext.ctx.call("goBack");
    }

    /**
     * <p>Navigates forward.</p>
     */
    public function goForward():void {
        if (safetyCheck())
            ANEContext.ctx.call("goForward");
    }

    /**
     *
     * @param offset Navigate forward (eg +1) or back (eg -1)
     *
     */
    public function go(offset:int = 1):void {
        if (safetyCheck())
            ANEContext.ctx.call("go", offset);
    }

    /**
     *
     * @return
     * <p><strong>Ignored on Windows and Android.</strong></p>
     */
    public function backForwardList():BackForwardList {
        if (safetyCheck())
            return ANEContext.ctx.call("backForwardList") as BackForwardList;
        return new BackForwardList();
    }

    /**
     * Forces a reload of the page (i.e. ctrl F5)
     *
     */
    public function reloadFromOrigin():void {
        if (safetyCheck())
            ANEContext.ctx.call("reloadFromOrigin");
    }

    /**
     *
     * @param fs When going fullscreen set this to true, when coming out of fullscreen set to false
     *
     */
    public function onFullScreen(fs:Boolean = false):void {
        //trace(_stage.width, _stage.height, _stage.stageWidth, _stage.stageHeight)
        if (safetyCheck())
            ANEContext.ctx.call("onFullScreen", fs);
    }

    /**
     *
     * @return Whether the page allows magnification functionality
     * <p><strong>Ignored on iOS.</strong></p>
     */
    public function allowsMagnification():Boolean {
        if (safetyCheck())
            return ANEContext.ctx.call("allowsMagnification");
        return false;
    }

    /**
     *
     * @return The current magnification level
     *
     */
    [Deprecated(message="Not available")]
    public function getMagnification():Number {
        return 1.0;
    }

    /**
     *
     * @param value
     * @param centeredAt
     * <p><strong>Ignored on iOS.</strong></p>
     */
    [Deprecated(replacement="zoomIn")]
    public function setMagnification(value:Number, centeredAt:Point):void {
    }

    /**
     * Zooms in
     *
     */
    public function zoomIn():void {
        if (safetyCheck())
            ANEContext.ctx.call("zoomIn");
    }

    /**
     * Zooms out
     *
     */
    public function zoomOut():void {
        if (safetyCheck())
            ANEContext.ctx.call("zoomOut");
    }

    public function addTab(initialUrl:String = null):void {
        if (safetyCheck())
            ANEContext.ctx.call("addTab", initialUrl);
    }

    public function closeTab(index:int):void {
        if (safetyCheck())
            ANEContext.ctx.call("closeTab", index);
    }

    public function set currentTab(value:int):void {
        if (safetyCheck())
            ANEContext.ctx.call("setCurrentTab", value);
    }

    public function get currentTab():int {
        var ct:int = 0;
        if (safetyCheck())
            ct = int(ANEContext.ctx.call("getCurrentTab"));
        return ct;
    }

    public function get tabDetails():Vector.<TabDetails> {
        var ret:Vector.<TabDetails> = new Vector.<TabDetails>();
        if (safetyCheck()) {
            ret = Vector.<TabDetails>(ANEContext.ctx.call("getTabDetails"));
        }
        return ret;

    }




    /**
     * This method is omitted from the output. * * @private
     */
    private function safetyCheck():Boolean {
        if (!_isInited) {
            trace("You need to init first");
            return false;
        }
        return _isSupported;
    }

    /**
     *
     * @return true if the device is Windows 7+, OSX 10.10+ or iOS 9.0+
     *
     */
    public function isSupported():Boolean {
        return _isSupported;
    }

    /**
     * <p>This cleans up the webview and all related processes.</p>
     * <p><strong>It is important to call this when the app is exiting.</strong></p>
     * @example
     * <listing version="3.0">
     NativeApplication.nativeApplication.addEventListener(flash.events.Event.EXITING, onExiting);
     private function onExiting(event:Event):void {
        webView.dispose();
     }</listing>
     *
     */
    public function dispose():void {
        if (!ANEContext.ctx) {
            trace("[" + name + "] Error. ANE Already in a disposed or failed state...");
            return;
        }
        trace("[" + name + "] Unloading ANE...");
        ANEContext.ctx.removeEventListener(StatusEvent.STATUS, gotEvent);
        ANEContext.ctx.dispose();
        ANEContext.ctx = null;
    }

    /**
     *
     * @return current url
     *
     */
    [Deprecated(replacement="tabDetails")]
    public function get url():String {
        return _url;
    }

    /**
     *
     * @return current page title
     *
     */
    [Deprecated(replacement="tabDetails")]
    public function get title():String {
        return _title;
    }

    /**
     *
     * @return whether the page is loading
     *
     */
    [Deprecated(replacement="tabDetails")]
    public function get isLoading():Boolean {
        return _isLoading;
    }

    /**
     *
     * @return whether we can navigate back
     *
     * <p>A Boolean value indicating whether we can navigate back.</p>
     *
     */
    [Deprecated(replacement="tabDetails")]
    public function get canGoBack():Boolean {
        return _canGoBack;
    }

    /**
     *
     * @return whether we can navigate forward
     *
     * <p>A Boolean value indicating whether we can navigate forward.</p>
     *
     */
    [Deprecated(replacement="tabDetails")]
    public function get canGoForward():Boolean {
        return _canGoForward;
    }

    /**
     *
     * @return estimated progress between 0.0 and 1.0.
     * Available on OSX only
     *
     */
    [Deprecated(replacement="tabDetails")]
    public function get estimatedProgress():Number {
        return _estimatedProgress;
    }

    /**
     * <p>Shows the Chromium dev tools on Windows</p>
     * <p>On Android use Chrome on connected computer and navigate to chrome://inspect</p>
     *
     */
    public function showDevTools():void {
        if (safetyCheck())
            ANEContext.ctx.call("showDevTools");
    }

    /**
     * <p>Close the Chromium dev tools</p>
     * <p>On Android disconnects from chrome://inspect</p>
     *
     */
    public function closeDevTools():void {
        if (safetyCheck())
            ANEContext.ctx.call("closeDevTools");
    }


    [Deprecated(message="combined into init params")]
    public function setBackgroundColor(value:uint, alpha:Number = 1.0):void {
        _backgroundColor = value;
        _backgroundAlpha = alpha;
    }

    /**
     *
     * @return whether we have inited the webview
     *
     */
    public function get isInited():Boolean {
        return _isInited;
    }

    /**
     *
     * @return current status message (This would normally appear on the bottom left of a browser)
     * <p><strong>Windows only.</strong></p>
     *
     */
    [Deprecated(replacement="tabDetails")]
    public function get statusMessage():String {
        return _statusMessage;
    }

    [Deprecated(message="This is not needed any more as shutdown of CEF is automatically handled in the dispose method")]
    public function shutDown():void {
    }

    public function focus():void {
        if (safetyCheck())
            ANEContext.ctx.call("focus");
    }

    /**
     *
     * @param code Javascript to inject, if any.
     * @param scriptUrl is the URL where the script in question can be found, if any. Windows only
     * @param startLine is the base line number to use for error reporting. Windows only
     *
     * <p>Specify either code or scriptUrl. These are injected into the main Frame when it is loaded. Call before
     * load() method</p>
     * <p><strong>Ignored on Android.</strong></p>
     */

    public function injectScript(code:String = null, scriptUrl:String = null, startLine:uint = 0):void {
        if (code != null || scriptUrl != null) {
            ANEContext.ctx.call("injectScript", code, scriptUrl, startLine);
        }
    }


    /**
     *
     * <p>prints the webView.</p>
     * <p><strong>Windows only.</strong></p>
     *
     */
    public function print():void {
        ANEContext.ctx.call("print");
    }

    /**
     *
     * @param x
     * @param y
     * @param width leaving as default of 0 captures the full width
     * @param height leaving as default of 0 captures the full height
     *
     * <p>Captures the webView to BitmapData.</p>
     * <p><strong>Windows only.</strong></p>
     *
     */
    public function capture(x:int = 0, y:int = 0, width:int = 0, height:int = 0):BitmapData {
        return ANEContext.ctx.call("capture", x, y, width, height) as BitmapData;
    }

    /**
     *
     * @param value
     *
     */
    public function set visible(value:Boolean):void {
        if (_visible == value) return;
        _visible = value;
        if (safetyCheck()) {
            if (value) {
                ANEContext.ctx.call("addToStage");
            } else {
                ANEContext.ctx.call("removeFromStage");
            }
        }
    }

    /**
     *
     * @return whether the webView is visible
     *
     */
    public function get visible():Boolean {
        return _visible;
    }

    public function get viewPort():Rectangle {
        return _viewPort;
    }

    /**
     *
     * @param value
     * <p>Sets the viewPort of the webView.</p>
     *
     */
    public function set viewPort(value:Rectangle):void {
        _viewPort = value;
        if (safetyCheck()) {
            ANEContext.ctx.call("setPositionAndSize", _viewPort);
        }

    }


}
}
