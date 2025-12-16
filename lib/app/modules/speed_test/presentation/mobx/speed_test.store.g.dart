// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speed_test.store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SpeedTestStore on _SpeedTestStore, Store {
  Computed<bool>? _$hasConnectionComputed;

  @override
  bool get hasConnection =>
      (_$hasConnectionComputed ??= Computed<bool>(() => super.hasConnection,
              name: '_SpeedTestStore.hasConnection'))
          .value;
  Computed<String>? _$connectionNameComputed;

  @override
  String get connectionName =>
      (_$connectionNameComputed ??= Computed<String>(() => super.connectionName,
              name: '_SpeedTestStore.connectionName'))
          .value;
  Computed<IconData>? _$connectionIconComputed;

  @override
  IconData get connectionIcon => (_$connectionIconComputed ??=
          Computed<IconData>(() => super.connectionIcon,
              name: '_SpeedTestStore.connectionIcon'))
      .value;
  Computed<Color>? _$connectionColorComputed;

  @override
  Color get connectionColor => (_$connectionColorComputed ??= Computed<Color>(
          () => super.connectionColor,
          name: '_SpeedTestStore.connectionColor'))
      .value;
  Computed<bool>? _$hasTestResultsComputed;

  @override
  bool get hasTestResults =>
      (_$hasTestResultsComputed ??= Computed<bool>(() => super.hasTestResults,
              name: '_SpeedTestStore.hasTestResults'))
          .value;

  late final _$downloadRateAtom =
      Atom(name: '_SpeedTestStore.downloadRate', context: context);

  @override
  double get downloadRate {
    _$downloadRateAtom.reportRead();
    return super.downloadRate;
  }

  @override
  set downloadRate(double value) {
    _$downloadRateAtom.reportWrite(value, super.downloadRate, () {
      super.downloadRate = value;
    });
  }

  late final _$uploadRateAtom =
      Atom(name: '_SpeedTestStore.uploadRate', context: context);

  @override
  double get uploadRate {
    _$uploadRateAtom.reportRead();
    return super.uploadRate;
  }

  @override
  set uploadRate(double value) {
    _$uploadRateAtom.reportWrite(value, super.uploadRate, () {
      super.uploadRate = value;
    });
  }

  late final _$latencyAtom =
      Atom(name: '_SpeedTestStore.latency', context: context);

  @override
  int? get latency {
    _$latencyAtom.reportRead();
    return super.latency;
  }

  @override
  set latency(int? value) {
    _$latencyAtom.reportWrite(value, super.latency, () {
      super.latency = value;
    });
  }

  late final _$isServerSelectionInProgressAtom = Atom(
      name: '_SpeedTestStore.isServerSelectionInProgress', context: context);

  @override
  bool get isServerSelectionInProgress {
    _$isServerSelectionInProgressAtom.reportRead();
    return super.isServerSelectionInProgress;
  }

  @override
  set isServerSelectionInProgress(bool value) {
    _$isServerSelectionInProgressAtom
        .reportWrite(value, super.isServerSelectionInProgress, () {
      super.isServerSelectionInProgress = value;
    });
  }

  late final _$isTestingAtom =
      Atom(name: '_SpeedTestStore.isTesting', context: context);

  @override
  bool get isTesting {
    _$isTestingAtom.reportRead();
    return super.isTesting;
  }

  @override
  set isTesting(bool value) {
    _$isTestingAtom.reportWrite(value, super.isTesting, () {
      super.isTesting = value;
    });
  }

  late final _$testProgressAtom =
      Atom(name: '_SpeedTestStore.testProgress', context: context);

  @override
  double get testProgress {
    _$testProgressAtom.reportRead();
    return super.testProgress;
  }

  @override
  set testProgress(double value) {
    _$testProgressAtom.reportWrite(value, super.testProgress, () {
      super.testProgress = value;
    });
  }

  late final _$currentTestPhaseAtom =
      Atom(name: '_SpeedTestStore.currentTestPhase', context: context);

  @override
  String get currentTestPhase {
    _$currentTestPhaseAtom.reportRead();
    return super.currentTestPhase;
  }

  @override
  set currentTestPhase(String value) {
    _$currentTestPhaseAtom.reportWrite(value, super.currentTestPhase, () {
      super.currentTestPhase = value;
    });
  }

  late final _$serverIpAtom =
      Atom(name: '_SpeedTestStore.serverIp', context: context);

  @override
  String? get serverIp {
    _$serverIpAtom.reportRead();
    return super.serverIp;
  }

  @override
  set serverIp(String? value) {
    _$serverIpAtom.reportWrite(value, super.serverIp, () {
      super.serverIp = value;
    });
  }

  late final _$connectionInfoAtom =
      Atom(name: '_SpeedTestStore.connectionInfo', context: context);

  @override
  ConnectionInfo? get connectionInfo {
    _$connectionInfoAtom.reportRead();
    return super.connectionInfo;
  }

  @override
  set connectionInfo(ConnectionInfo? value) {
    _$connectionInfoAtom.reportWrite(value, super.connectionInfo, () {
      super.connectionInfo = value;
    });
  }

  late final _$isConnectionCardExpandedAtom =
      Atom(name: '_SpeedTestStore.isConnectionCardExpanded', context: context);

  @override
  bool get isConnectionCardExpanded {
    _$isConnectionCardExpandedAtom.reportRead();
    return super.isConnectionCardExpanded;
  }

  @override
  set isConnectionCardExpanded(bool value) {
    _$isConnectionCardExpandedAtom
        .reportWrite(value, super.isConnectionCardExpanded, () {
      super.isConnectionCardExpanded = value;
    });
  }

  late final _$loadConnectionInfoAsyncAction =
      AsyncAction('_SpeedTestStore.loadConnectionInfo', context: context);

  @override
  Future<void> loadConnectionInfo() {
    return _$loadConnectionInfoAsyncAction
        .run(() => super.loadConnectionInfo());
  }

  late final _$runTestAsyncAction =
      AsyncAction('_SpeedTestStore.runTest', context: context);

  @override
  Future<void> runTest() {
    return _$runTestAsyncAction.run(() => super.runTest());
  }

  late final _$_SpeedTestStoreActionController =
      ActionController(name: '_SpeedTestStore', context: context);

  @override
  void _setupConnectivityListener() {
    final _$actionInfo = _$_SpeedTestStoreActionController.startAction(
        name: '_SpeedTestStore._setupConnectivityListener');
    try {
      return super._setupConnectivityListener();
    } finally {
      _$_SpeedTestStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void reset() {
    final _$actionInfo = _$_SpeedTestStoreActionController.startAction(
        name: '_SpeedTestStore.reset');
    try {
      return super.reset();
    } finally {
      _$_SpeedTestStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleConnectionCardExpanded() {
    final _$actionInfo = _$_SpeedTestStoreActionController.startAction(
        name: '_SpeedTestStore.toggleConnectionCardExpanded');
    try {
      return super.toggleConnectionCardExpanded();
    } finally {
      _$_SpeedTestStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setServerSelectionInProgress(bool value) {
    final _$actionInfo = _$_SpeedTestStoreActionController.startAction(
        name: '_SpeedTestStore.setServerSelectionInProgress');
    try {
      return super.setServerSelectionInProgress(value);
    } finally {
      _$_SpeedTestStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
downloadRate: ${downloadRate},
uploadRate: ${uploadRate},
latency: ${latency},
isServerSelectionInProgress: ${isServerSelectionInProgress},
isTesting: ${isTesting},
testProgress: ${testProgress},
currentTestPhase: ${currentTestPhase},
serverIp: ${serverIp},
connectionInfo: ${connectionInfo},
isConnectionCardExpanded: ${isConnectionCardExpanded},
hasConnection: ${hasConnection},
connectionName: ${connectionName},
connectionIcon: ${connectionIcon},
connectionColor: ${connectionColor},
hasTestResults: ${hasTestResults}
    ''';
  }
}
