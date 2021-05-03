import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:reflex/models/constants.dart';
import 'package:reflex/services/services.dart';
import 'package:reflex/views/club_info.dart';
import 'package:reflex/views/share_photo_screen.dart';
import 'package:reflex/widgets/widget.dart';

class ClubMessagingScreen extends StatefulWidget {
  final String _clubId;
  final String _clubProfileImage;
  final String _clubName;
  final String _clubDescription;
  final String _clubCategory;

  ClubMessagingScreen(
    this._clubId,
    this._clubProfileImage,
    this._clubName,
    this._clubDescription,
    this._clubCategory,
  );

  @override
  _ClubMessagingScreenState createState() => _ClubMessagingScreenState();
}

class _ClubMessagingScreenState extends State<ClubMessagingScreen> {
  TextEditingController _textController = TextEditingController();
  final _controller = ScrollController();
  int _membersNum = 0;

  playMessageSentTone() {
    print('sent');
  }

  _getMembersNum() async {
    await kClubsRef
        .doc(widget._clubId)
        .collection('Members')
        .where('joinState', isEqualTo: 'Joined')
        .get()
        .then((myDocuments) {
      if (mounted) {
        setState(() {
          _membersNum = myDocuments.docs.length;
        });
      }
    });
  }

  plusButtonSheet() {
    Get.bottomSheet(
      Container(
        height: 220,
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
              'Share photo / Camera',
              () => Get.to(
                SharePhotoScreen(
                  widget._clubId,
                  widget._clubName,
                  true,
                ),
              ),
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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getMembersNum();
    updateClubLastRoomVisitTime(widget._clubId);

    messagesStreamBuilder = StreamBuilder<QuerySnapshot>(
      stream: kClubChatRoomsRef
          .doc(widget._clubId)
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
              child: myLoader(),
            ),
          );
        }

        if (snapshot.data.docs.length > 0) {
          Timer(
            Duration(milliseconds: 10),
            () => _controller.jumpTo(_controller.position.maxScrollExtent),
          );
        }

        if (snapshot.data.docs.length == 0) {
          return Container(
            height: 300,
            child: noDataSnapshotMessage(
              'Start a new conversation',
              Text('Learn more about each other'),
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
            return snapshot.data.docs[index]['senderId'] != null
                ? MessageItem(
                    snapshot.data.docs[index]['messageText'],
                    snapshot.data.docs[index]['sendTime'],
                    snapshot.data.docs[index]['senderId'],
                    snapshot.data.docs[index]['sender'],
                    snapshot.data.docs[index]['senderProfileImage'],
                    snapshot.data.docs[index]['messageImage'],
                    snapshot.data.docs[index]['messageType'],
                    snapshot.data.docs[index].id,
                    widget._clubId,
                    true,
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
      color: Colors.black,
      child: SafeArea(
        child: Scaffold(
          body: Scaffold(
            backgroundColor: Get.isDarkMode ? Colors.black : Colors.white,
            appBar: AppBar(
              backgroundColor: !Get.isDarkMode ? Colors.white : kDarkThemeBlack,
              elevation: 0,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.to(
                      ClubInfoScreen(
                        widget._clubId,
                        widget._clubProfileImage,
                        widget._clubName,
                        widget._clubDescription,
                        widget._clubCategory,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: Hero(
                        tag: widget._clubId,
                        child: CircleAvatar(
                          backgroundColor: Get.isDarkMode
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          backgroundImage:
                              NetworkImage(widget._clubProfileImage),
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
                          widget._clubName,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: TextStyle(
                            color:
                                !Get.isDarkMode ? Colors.black : Colors.white,
                          ),
                        ),
                        Text(
                          _membersNum > 1
                              ? '$_membersNum members'
                              : '$_membersNum member',
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 12,
                            color: !Get.isDarkMode ? Colors.grey : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: kPrimaryColor,
                ),
                onPressed: () {
                  updateLastRoomVisitTime(widget._clubId);
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
              color: Get.isDarkMode ? kDarkThemeBlack : Colors.white,
              elevation: 0,
              child: Container(
                padding: EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        child: Icon(
                          CupertinoIcons.smiley_fill,
                          size: 25,
                          color: kPrimaryColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () => plusButtonSheet(),
                        child: Icon(
                          CupertinoIcons.plus_circle_fill,
                          size: 25,
                          color: kPrimaryColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        child: Icon(
                          CupertinoIcons.mic_fill,
                          size: 25,
                          color: kPrimaryColor,
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
                          onChanged: (value) {},
                          decoration: InputDecoration(
                            focusedBorder:
                                OutlineInputBorder(borderSide: BorderSide.none),
                            enabledBorder:
                                OutlineInputBorder(borderSide: BorderSide.none),
                            contentPadding: EdgeInsets.only(left: 15),
                            hintText: "Type a message...",
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: IconButton(
                        onPressed: () {
                          if (_textController.text.trim() != '') {
                            sendClubMessage(
                              widget._clubId,
                              _textController.text.trim(),
                            );

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
                    ),
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