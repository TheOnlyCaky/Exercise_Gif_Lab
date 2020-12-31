/*
* Christian Krueger Health LLC.
* All Rights Reserved.
*
* Author: Christian Krueger
* Date: 4.15.20
*
*/

//TODO rename this to disclaimer page
import 'package:exerciseGifLab/Models/models.dart';
import 'package:exerciseGifLab/Views/views.dart';
import 'package:exerciseGifLab/Controllers/controllers.dart';

class CameraDefines {
  static int cameraTime = 5;
}

class CameraPage extends StatefulWidget {

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  BoolBLoC _cameraReadyBloc = BoolBLoC(false);
  BoolBLoC _recordReadyBloc = BoolBLoC(false);
  IntBLoC _timerBloc = IntBLoC(0);

  double _screenWidth;
  double _screenHeight;
  double _screenTopPadding;
  double _middleWidth;
  double _buttonWidth;

  CameraController _controller;
  String _tempDir;
  String _currentPath;

  Timer _timer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
    
  }

  @override
  void dispose(){
    _cameraReadyBloc.dispose();
    _recordReadyBloc.dispose();
    _controller.dispose();
    if(_timer != null) _timer.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    List<CameraDescription> cameras;

    try {
      cameras = await availableCameras();
      _controller = CameraController(cameras.first, ResolutionPreset.low, enableAudio: false);
      await _controller.initialize();
      await _controller.prepareForVideoRecording();
      _tempDir = (await getTemporaryDirectory()).path;
      _cameraReadyBloc.add(BoolUpdateEvent(true));
      _recordReadyBloc.add(BoolUpdateEvent(true));
    } on CameraException catch (e) {
      print(e);
    }
  }

  void _buildDimentions(){
    MediaQueryData query = MediaQuery.of(context);
    _screenWidth = query.size.width;
    _screenHeight = query.size.height;
    _screenTopPadding = query.padding.top;
    _middleWidth = _screenWidth * CKHRatios.middleScreenWidthRatio;
    _buttonWidth = _middleWidth / CKHRatios.gold;
  }

  void _startTimer(){
    _timer = Timer(
      Duration(seconds: 1),
      _tickTimer
    );
  }

  void _tickTimer(){
    int newState = _timerBloc.state -1;
    if(newState <= 0){
      _timerBloc.add(IntUpdateEvent(0));
      _stopNSwap();
    } else {
      _timerBloc.add(IntUpdateEvent(newState));
      _startTimer();
    }
  }

  void _startRecording(){
    _currentPath = _tempDir + "ff_exercise${DateTime.now().millisecondsSinceEpoch}.MOV";

    _recordReadyBloc.add(BoolUpdateEvent(false));
    _controller.startVideoRecording(_currentPath).then((_){
      _timerBloc.add(IntUpdateEvent(CameraDefines.cameraTime));
      _startTimer();

    }, onError: (_){
      LOG.log("Error starting recording", 1);
    });
  }

  void _stopNSwap(){
    try {
      _controller.stopVideoRecording().then((_){
        GallerySaver.saveVideo(_currentPath, albumName: "FF Exercises").then((didSave){
          if(!didSave){
            LOG.log("Failed to save", 2);
          }
          _recordReadyBloc.add(BoolUpdateEvent(true));
        }, onError: (_){
          LOG.log("Error saving video to gallery", 1);
          _recordReadyBloc.add(BoolUpdateEvent(true));
        });
      }, onError: (_){
        LOG.log("Error stopping the recording", 1);
        _recordReadyBloc.add(BoolUpdateEvent(true));
      });
    } on CameraException catch (e) {
      print(e);
    }

  }

  Widget _buildOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black54,
        BlendMode.srcOut
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: _middleWidth,
                width: _middleWidth,
                decoration: BoxDecoration(
                  color: Colors.black, // Color does not matter but should not be transparent
                  borderRadius: BorderRadius.circular(34),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCamera(){
    return BlocBuilder(
      cubit: _cameraReadyBloc,
      builder: (context, isReady) {
        if(!isReady) return Container(color: CKHColors.main,);

        double deviceRatio = _screenWidth / _screenHeight;

        return Center(
          child: Transform.scale(
            scale: _controller.value.aspectRatio / deviceRatio,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: CameraPreview(
                  _controller
                ),
              ),
            )
          ),
        );
      }
    );
  }

  Widget _buildButtonRack(){
    return Positioned.fill(
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.only(bottom: 55),
          child: Align(
           alignment: Alignment.bottomCenter,
            child: BlocBuilder(
              cubit: _recordReadyBloc,
              builder: (context, recordReady) {
                return BlocBuilder(
                  cubit: _timerBloc,
                  builder: (context, timeLeft) {
                    return MaterialButton(
                      onPressed: () {
                        if(timeLeft == 0 && recordReady){
                          _startRecording();
                        }
                      },
                      color: (recordReady) ? CKHColors.main : CKHColors.secondary,
                      textColor: CKHColors.tertiary,
                      child: 
                      (timeLeft > 0) ?
                        AST(
                          timeLeft.toString(),
                          color: CKHColors.tertiary,
                          isBold: true,
                          size: 55,
                        ) :
                        Icon(
                          FontAwesomeIcons.recordVinyl,
                          size: 55,
                        ),
                      padding: EdgeInsets.all(16),
                      shape: CircleBorder(),
                    );
                  }
                );
              }
            ),
          ),
        ),
      ),
    );
  }

  CameraController controller;

  @override
  Widget build(BuildContext context) {
    _buildDimentions();

    return Scaffold(
      body: Stack(
        children: [
          _buildCamera(),
          _buildOverlay(),
          _buildButtonRack(),
        ]
      )
    );
  }
}
