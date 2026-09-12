import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

var host = dotenv.env['HOST'];

// Enhancement 3: the cart belongs to a single user, so the id is fixed here
// rather than being scattered through the screens.
const int kCartUserId = 1;

const Color kPrimaryNavy = Color(0xFF2B3990);
const Color kAccentAmber = Color(0xFFFFC02D);
const Color kScreenGrey = Color(0xFFF2F2F7);
