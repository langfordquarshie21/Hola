import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart' hide Key;
import 'package:flutter/material.dart' hide Key;
import 'package:get/get.dart';
import 'package:reflex/models/constants.dart';
import 'package:reflex/services/services.dart';
import 'package:reflex/views/user.dart';
import 'package:reflex/widgets/widget.dart';

class MessagingScreen extends StatefulWidget {
  final String _name;
  final String _profilePhoto;
  final String _userId;
  MessagingScreen(this._name, this._profilePhoto, this._userId);

  @override
  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final _controller = ScrollController();
  var percentage = 0;
  String _roomId = '';
  TextEditingController _textController = TextEditingController();
  bool loading = false;
  bool isTyping = false;
  bool _isUserTyping = false;

  // final AudioCache player = AudioCache();
  // final alarmAudioPath = "messageSent.mp3";

  playMessageSentTone() {
    // player.play(alarmAudioPath);
    //
    //
    //  AudioCache cache = new AudioCache();
    //At the next line, DO NOT pass the entire reference such as assets/yes.mp3. This will not work.
    //Just pass the file name only.
    //  cache.play("messageSent.mp3");
    //
    //
    //
  }

  Future checkRoomExist() async {
    try {
      setState(() {
        _roomId = getRoomId(widget._userId);
      });

      DocumentReference roomsRef = kChatRoomsRef.doc(_roomId);

      await roomsRef.get().then(
        (doc) {
          if (!doc.exists) {
            createRoom(_roomId, widget._userId);
            updateRoomToken(_roomId);
            updateLastRoomVisitTime(_roomId);
          }
        },
      );
    } catch (e) {
      singleButtonDialogue('Sorry, an unexpected error occured');
    }
  }

  Future _pickImages() async {
    FilePickerResult result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'gif'],
    );

    if (result != null) {
      List<File> files = result.paths.map((path) => File(path)).toList();
      setState(() {});
      print(files.length);

      _uploadImages(files);

      Get.back();
      Timer(
        Duration(milliseconds: 1),
        () => _controller.jumpTo(_controller.position.maxScrollExtent),
      );
    } else {
      // User canceled the picker
    }
  }

  Future _uploadImages(List<File> _files) async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    List _allUrls = [];

    try {
      for (int i = 0; i < _files.length; i++) {
        print(i);

        String filePath = 'imagePosts/${DateTime.now()}.jpg';

        FirebaseStorage storage = FirebaseStorage.instance;

        UploadTask uploadTask =
            storage.ref().child(filePath).putFile(_files[i]);

        TaskSnapshot taskSnapshot = await uploadTask;

        if (mounted) {
          setState(() {
            var t = taskSnapshot.bytesTransferred.toInt();
            var q = taskSnapshot.totalBytes.toInt();

            percentage = taskSnapshot.bytesTransferred;
          });
        }

        await uploadTask.whenComplete(() => print('complete upload'));

        String imageUrl = await taskSnapshot.ref.getDownloadURL();

        _allUrls.add(imageUrl);
      }

      if (mounted) {
        setState(() {
          loading = false;
        });
      }

      await sendPhoto(_allUrls, _roomId, false);

      await updateRoomLastInfo(_roomId, '🌄 Sent a photo');
    } catch (e) {
      print(e);

      singleButtonDialogue(e);

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  plusButtonSheet() {
    Get.bottomSheet(
      Container(
        height: 260,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Get.isDarkMode ? kDarkThemeBlack : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
        ),
        child: Column(
          children: [
            bottomSheetItem(
              Icon(CupertinoIcons.photo, color: kPrimaryColor),
              'Share photo',
              () => _pickImages(),
            ),
            SizedBox(height: 20),
            bottomSheetItem(
              Icon(CupertinoIcons.camera, color: kPrimaryColor),
              'Open camera',
              () => _pickImages(),
            ),
            SizedBox(height: 20),
            bottomSheetItem(
              Icon(CupertinoIcons.keyboard, color: kPrimaryColor),
              'Use voice typing',
              () {},
            ),
            SizedBox(height: 20),
            bottomSheetItem(
              Icon(CupertinoIcons.folder, color: kPrimaryColor),
              'Send a file',
              () {},
            ),
            SizedBox(height: 20),
            bottomSheetItem(
              Icon(CupertinoIcons.smiley, color: kPrimaryColor),
              'Share sticker / GIF',
              () {},
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  var messagesStreamBuilder;

  encryptMessage() {
    final plainText = _textController.text.trim();

    final key = Key.fromLength(32);
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(key));

    final encrypted = encrypter.encrypt(plainText, iv: iv);

    sendMessage(
      _roomId,
      widget._userId,
      encrypted.base64,
    );
  }

  _getTypingState() {
    kChatRoomsRef
        .doc(_roomId)
        .collection('RoomLogs')
        .doc(widget._userId)
        .snapshots()
        .listen((event) {
      if (mounted) {
        setState(() {
          _isUserTyping = event.data()['isTyping'];
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    checkRoomExist();
    _roomId = getRoomId(widget._userId);
    updateLastRoomVisitTime(_roomId);
    _getTypingState();

    messagesStreamBuilder = StreamBuilder<QuerySnapshot>(
      stream: kChatRoomsRef
          .doc(_roomId)
          .collection('RoomMessages')
          .orderBy('sendTime')
          .snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error fetching messages...',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Text('Fetching history...'),
            ),
          );
        }

        if (snapshot.data.docs.length > 0) {
          Timer(
            Duration(milliseconds: 3),
            () => _controller.jumpTo(_controller.position.maxScrollExtent),
          );
        }

        if (snapshot.data.docs.length == 0) {
          return Container(
            child: noRoomChatsMessage(
              widget._profilePhoto,
              widget._name,
              widget._userId,
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: Text(
              'Sorry, an error occured...',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data.docs.length,
          shrinkWrap: true,
          primary: false,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final key = Key.fromLength(32);
            final iv = IV.fromLength(16);
            final encrypter = Encrypter(AES(key));

            var messageText = encrypter
                .decrypt64(snapshot.data.docs[index]['messageText'], iv: iv)
                .toString();

            return snapshot.data.docs[index]['senderId'] != null
                ? MessageItem(
                    messageText,
                    snapshot.data.docs[index]['sendTime'],
                    snapshot.data.docs[index]['senderId'],
                    snapshot.data.docs[index]['sender'],
                    snapshot.data.docs[index]['senderProfileImage'],
                    snapshot.data.docs[index]['messageImage'],
                    snapshot.data.docs[index]['messageType'],
                    snapshot.data.docs[index].id,
                    _roomId,
                    false,
                  )
                : Container();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Get.isDarkMode ? kDarkBodyThemeBlack : Colors.black,
      child: SafeArea(
        child: Scaffold(
          body: Scaffold(
            backgroundColor: Get.isDarkMode ? Colors.grey[800] : Colors.white,
            appBar: AppBar(
              backgroundColor:
                  !Get.isDarkMode ? Colors.white : Colors.grey[900],
              elevation: kShadowInt,
              titleSpacing: 0,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () => widget._userId != kMyId
                        ? Get.to(
                            UserScreen(
                              widget._userId,
                              widget._profilePhoto,
                              widget._name,
                            ),
                          )
                        : () {},
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: Hero(
                        tag: widget._userId,
                        child: CircleAvatar(
                          backgroundColor: Get.isDarkMode
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          backgroundImage: NetworkImage(widget._profilePhoto),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget._name,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: TextStyle(
                            color:
                                !Get.isDarkMode ? Colors.black : Colors.white,
                          ),
                        ),
                        _isUserTyping != null && _isUserTyping
                            ? Text(
                                _isUserTyping ? 'is typing...' : 'active',
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: !Get.isDarkMode
                                      ? Colors.grey
                                      : Colors.white,
                                ),
                              )
                            : Container(),
                      ],
                    ),
                  ),
                ],
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: kPrimaryColor,
                ),
                onPressed: () {
                  updateLastRoomVisitTime(_roomId);
                  Get.back();
                },
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: kPrimaryColor,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
            bottomNavigationBar: BottomAppBar(
              color: Get.isDarkMode ? Colors.grey[900] : Colors.white,
              elevation: 0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        child: Icon(
                          CupertinoIcons.smiley,
                          size: 25,
                          // color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () => plusButtonSheet(),
                        child: Icon(
                          CupertinoIcons.plus_square,
                          size: 25,
                          // color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Get.isDarkMode
                              ? Colors.transparent
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: TextFormField(
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          controller: _textController,
                          onChanged: (value) {
                            if (mounted) {
                              setState(() {
                                isTyping = true;
                              });
                            }

                            setTypingState(isTyping, _roomId);

                            Timer(Duration(seconds: 2), () {
                              if (mounted) {
                                setState(() {
                                  isTyping = false;
                                });
                              }

                              setTypingState(isTyping, _roomId);
                            });
                          },
                          decoration: InputDecoration(
                            focusedBorder:
                                OutlineInputBorder(borderSide: BorderSide.none),
                            enabledBorder:
                                OutlineInputBorder(borderSide: BorderSide.none),
                            contentPadding: EdgeInsets.only(left: 15),
                            hintText: "Type a message...",
                            hintStyle: TextStyle(
                              fontSize: 14,
                              // color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _textController.text.isNotEmpty
                        ? Container(height: 0, width: 0)
                        : Expanded(
                            flex: 1,
                            child: GestureDetector(
                              child: Icon(
                                CupertinoIcons.mic,
                                size: 25,
                                // color: Colors.grey[800],
                              ),
                            ),
                          ),
                    _textController.text.isNotEmpty
                        ? Expanded(
                            flex: 1,
                            child: IconButton(
                              onPressed: () {
                                if (_textController.text.trim() != '') {
                                  encryptMessage();
                                  _textController.text = '';
                                } else
                                  return;
                              },
                              icon: Icon(
                                CupertinoIcons.paperplane_fill,
                                size: 25,
                                color: kPrimaryColor,
                              ),
                            ),
                          )
                        : Container(width: 0, height: 0),
                  ],
                ),
              ),
            ),
            body: Container(
              decoration: BoxDecoration(
                color: Get.isDarkMode ? kDarkBodyThemeBlack : Colors.white,
              ),
              height: MediaQuery.of(context).size.height,
              child: SingleChildScrollView(
                controller: _controller,
                child: Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      messagesStreamBuilder,
                      loading
                          ? Column(
                              children: [
                                SizedBox(height: 30),
                                myLoader(),
                                SizedBox(height: 10),
                                Text('Sending photo... $percentage%'),
                                SizedBox(height: 30),
                              ],
                            )
                          : Container(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
