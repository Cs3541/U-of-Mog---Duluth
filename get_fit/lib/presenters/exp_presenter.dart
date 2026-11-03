import '../models/exp_model.dart';

class ExpPresenter {
  Stream<ExpStatus> watchExp(String uid) => ExpRules.watchExp(uid);
}