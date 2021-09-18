import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'builders/on_reactive.dart';

import 'common/consts.dart';
import 'common/helper_method.dart';
import 'common/logger.dart';
import 'injected/injected_animation/injected_animation.dart';
import 'injected/injected_auth/injected_auth.dart';
import 'injected/injected_crud/injected_crud.dart';
import 'injected/injected_i18n/injected_i18n.dart';
import 'injected/injected_scrolling/injected_scrolling.dart';
import 'injected/injected_tab/injected_page_tab.dart';
import 'injected/injected_text_editing/injected_text_editing.dart';
import 'injected/injected_theme/injected_theme.dart';
import 'legacy/injector.dart';

part 'basics/depends_on.dart';
part 'basics/injected.dart';
part 'basics/injected_base_state.dart';
part 'basics/injected_base.dart';
part 'basics/injected_imp.dart';
part 'basics/injected_persistance/i_persist_store.dart';
part 'basics/injected_persistance/injected_persistance.dart';
part 'basics/injected_persistance/persist_state_mock.dart';
// part 'basics/injected_state.dart';
part 'basics/reactive_model.dart';
part 'basics/reactive_model_base.dart';
part 'basics/reactive_model_listener.dart';
part 'basics/snap_state.dart';
part 'basics/state_builder.dart';
part 'basics/undo_redo_persist_state.dart';
part 'extensions/injected_list_x.dart';
part 'extensions/injected_x.dart';
part 'extensions/on_combined_x.dart';
part 'extensions/on_future_x.dart';
part 'extensions/on_x.dart';
part 'navigate/build_context_x.dart';
part 'navigate/page_route_builder.dart';
part 'navigate/rm_navigator.dart';
part 'navigate/rm_scaffold.dart';
part 'navigate/route_data.dart';
part 'navigate/route_full_widget.dart';
part 'navigate/route_widget.dart';
part 'navigate/sub_route.dart';
part 'navigate/transitions.dart';
part 'on_listeners/on.dart';
part 'on_listeners/on_combined.dart';
part 'on_listeners/on_future.dart';
part 'builders/on_builder.dart';

abstract class RM {
  RM._();

  /// Injection of a primitive, enum, or object.
  ///
  /// State can be injected globally or scoped locally:
  ///
  /// Scoped locally means that the state's flow is encapsulated withing the widget
  /// and its children. If more than one widget is created, each has its own
  /// independent state.
  ///
  /// * Global state:
  ///
  ///   ```dart
  ///   //In the global scope
  ///   final myState = RM.inject(() => MyState())
  ///   ```
  ///   // Or Encapsulate it inside a business logic class (BLOC):
  ///   ```dart
  ///   //For the sake of best practice, one strives to make the class immutable
  ///   @immutable
  ///   class MyBloc {  // or MyViewModel, or MyController
  ///     final _myState1 = RM.inject(() => MyState1())
  ///     final _myState2 = RM.inject(() => MyState2())
  ///
  ///     //Other logic that mutate _myState1 and _myState2
  ///   }
  ///
  ///   //As MyBloc is immutable, it is safe to instantiate it globally
  ///   final myBloc = MyBloc();
  ///   ```
  ///
  /// * Scoped state (local state)
  ///
  ///   If the state or the Bloc are configurable (parametrized), Just declare
  ///   them globally and override the state in the widget tree.
  ///   ```dart
  ///   // The state will be initialized in the widget tree.
  ///   final myState = RM.inject(() => throw UnimplementedError())
  ///
  ///   // In the widget tree
  ///   myState.inherited(
  ///     stateOverride: () {
  ///       return MyState(parm1,param2);
  ///     },
  ///     builder: (context) {
  ///       // Read the state through the context
  ///       final _myState = myState.of(context);
  ///     }
  ///   )
  ///   ```
  ///   Similar with Blocs
  ///   ```dart
  ///   final myBloc = RM.inject<MyBloc>(() => throw UnimplementedError())
  ///
  ///   //In the widget tree
  ///   myState.inherited(
  ///     stateOverride: () {
  ///       return MyBloc(parm1, param2);
  ///     },
  ///     builder: (context) {
  ///       final _myBloc = myBloc.of(context);
  ///     }
  ///   )
  ///   ```
  /// ## Parameters:
  /// ### 1. creator: Required callback that returns `<T>`
  /// A callback that is used to create an instance of the injected object.
  /// It is called when:
  ///   * The state is first initialized
  ///   * The state is refreshed by calling [InjectedBase.refresh] method.
  ///   * Any of the states that it depends on emits a notification.
  ///
  /// {@template injectOptionalParameter}
  /// ### 2. initialState: Optional `<T>`
  /// The initial state. It is useful when injecting Future or Stream. If you
  /// try to get the state of non-resolved Future or Stream of non-nullable state,
  /// it will throw if `initialState` is not defined.
  ///
  /// ### 3. autoDisposeWhenNotUsed**: Optional [bool] (Default true)
  /// Whether to auto dispose the injected model when no longer used
  /// (listened to).
  ///
  /// It is important to note that:
  /// * A state never listened to for rebuild, never auto dispose even after it
  /// is mutated.
  /// * By default, all states consumed in the widget tree will auto dispose.
  /// * It is recommended to manually dispose state that are not auto disposed
  /// using [InjectedBaseState.dispose]. You can dispose all states of the app
  /// using [RM.disposeAll].
  /// * A state will auto dispose if all states it depends on are disposed of.
  /// * Non disposed state may lead to unexpected behavior.
  /// * To debug when state is initialized and disposed of use
  /// `debugPrintWhenNotifiedPreMessage` parameter (See below)
  ///
  /// ### 4. sideEffects: Optional [SideEffects]
  /// Used to handle sideEffects when the state is initialized, mutated and
  /// disposed of. Side effects defined here are called global (default) and
  /// can be overridden when calling [InjectedBase.setState] method.
  ///
  /// See also: [InjectedBase.setState], [OnBuilder.sideEffects] and [OnReactive.sideEffects]
  ///
  /// ### 5. onInitialized: Optional callback That exposed the state
  /// Callback to be executed after the injected model is first created. It is
  /// similar to [SideEffects.initState] except that it exposes the state for
  /// some useful cases.
  ///
  /// If the injected state is stream, onInitialized additionally exposes the
  /// [StreamSubscription] object to be able to pause the stream.
  ///
  /// ### 6. dependsOn: optional [DependsOn]
  /// Use to defined other injected states that this state depends on. When
  /// any of states it depends on is notified, this state is also notified and
  /// its creator is re-invoked. The state status will reflect a combination of
  /// the state status of dependencies:
  /// * If any of dependency state isWaiting, this state isWaiting.
  /// * If any of dependency state hasError, this state hasError.
  /// * If any of dependency state isIdle, this state isIdle.
  /// * If all dependency states have data, this state hasData.
  ///
  /// You can set when the state should be recreated, the time of debounce
  /// and the time of throttle.
  ///
  /// ### 7. undoStackLength: Optional integer
  /// It defines the length of the undo/redo stack. If not defined, the
  /// undo/redo is disabled.
  ///
  /// For the undo/redo state to work properly, the state must be immutable.
  ///
  /// Further on to undo or redo the state just call [Injected.undoState] and
  /// [Injected.redoState]
  ///
  /// ### 8. persist: Optional callback that return [PersistState]
  /// If defined, the state will be persisted.
  ///
  /// You have to provide a class that implements [IPersistStore] and initialize
  /// it in the main method.
  ///
  /// For example
  /// ```dart
  /// class IPersistStoreImp implements IPersistStore{
  ///  // ....
  /// }
  /// void main()async{
  ///  WidgetsFlutterBinding.ensureInitialized();
  ///
  ///  await RM.storageInitializer(IPersistStoreImp());
  ///  runApp(MyApp());
  /// }
  /// ```
  /// By default the state is persisted whenever is mutated, but you can set it
  /// to be persisted manually, or once the state is disposed.
  ///
  /// You can debounce and throttle state persistence.
  ///
  /// ### 9. stateInterceptor: Optional callback that exposes the current and
  /// next [SnapState]
  /// This call back is fired after on state mutation and exposes both the
  /// current state just before mutation and the next state.
  ///
  /// The callback return the next [SnapState]. It may be the same as next state
  /// or you can change it. Useful in many scenarios where we want to concatenate
  /// both current and next snap (fetch for list of items is an example);
  ///
  /// Example:
  /// ```dart
  /// final myState = RM.inject(
  ///  () => [],
  ///  stateInterceptor: (currentSnap, nextSnap) {
  ///    return nextSnap.copyTo(data: [
  ///      ...currentSnap.state,
  ///      ...nextSnap.state,
  ///    ]);
  ///  },
  /// );
  /// /// later on
  /// myState.state = ['one'];
  /// print(myState.state); // ['one']
  ///
  /// myState.state = ['two'];
  /// print(myState.state); // ['one', 'two']
  ///
  /// ```
  ///
  /// ### 10. debugPrintWhenNotifiedPreMessage: Optional [String]
  /// if not null, print an informative message when this model is notified in
  /// the debug mode. It prints (FROM ==> TO state). The entered message will
  /// pré-append the debug message. Useful if the type of the injected model
  /// is primitive to distinguish between them.
  ///
  /// ### 11. toDebugString: Optional callback that exposes the state
  /// String representation fo the state to be used in
  ///  `debugPrintWhenNotifiedPreMessage`. Useful, for example, if the state is a
  ///  collection and you want to print its length only.
  ///  {@endtemplate}
  ///
  ///
  static Injected<T> inject<T>(
    T Function() creator, {
    T? initialState,
    @Deprecated('Use stateInterceptor instead')
        SnapState<T>? Function(MiddleSnapState<T> middleSnap)? middleSnapState,
    SnapState<T>? Function(SnapState<T> currentSnap, SnapState<T> nextSnap)?
        stateInterceptor,
    void Function(T? s)? onInitialized,
    @Deprecated('Use sideEffects instead') void Function(T s)? onDisposed,
    @Deprecated('Use sideEffects instead') void Function()? onWaiting,
    @Deprecated('Use sideEffects instead') void Function(T s)? onData,
    @Deprecated('Use sideEffects instead') On<void>? onSetState,
    @Deprecated('Use sideEffects instead')
        void Function(dynamic e, StackTrace? s)? onError,
    SideEffects<T>? sideEffects,
    DependsOn<T>? dependsOn,
    //
    int undoStackLength = 0,
    PersistState<T> Function()? persist,
    //
    bool isLazy = true,
    //
    bool autoDisposeWhenNotUsed = true,
    String? debugPrintWhenNotifiedPreMessage,
    String Function(T?)? toDebugString,
  }) {
    late final InjectedImp<T> inj;

    inj = InjectedImp<T>(
      creator: creator,
      initialState: initialState,
      onInitialized: sideEffects?.initState != null
          ? (_) => sideEffects!.initState!()
          : onInitialized,
      onSetState: On(
        () {
          sideEffects
            ?..onSetState?.call(inj.snapState)
            ..onAfterBuild?.call();
          onSetState?.call(inj.snapState);
        },
      ),
      onWaiting: onWaiting,
      onDataForSideEffect: onData,
      onError: onError,
      onDisposed: sideEffects?.dispose != null
          ? (_) => sideEffects!.dispose!()
          : onDisposed,
      dependsOn: dependsOn,
      undoStackLength: undoStackLength,
      persist: persist,
      middleSnapState: stateInterceptor != null
          ? (middleSnap) => stateInterceptor(
                middleSnap.currentSnap,
                middleSnap.nextSnap,
              )
          : middleSnapState,
      isLazy: isLazy,
      debugPrintWhenNotifiedPreMessage: debugPrintWhenNotifiedPreMessage,
      toDebugString: toDebugString,
      autoDisposeWhenNotUsed: autoDisposeWhenNotUsed,
    );
    return inj;
  }

  /// injection of a [Future].
  ///
  /// ## Parameters:
  /// ### 1. creator: Required callback that returns [Future]
  /// A callback that is used to create an instance of the injected object.
  /// It is called when:
  ///   * The state is first initialized
  ///   * The state is refreshed by calling [InjectedBase.refresh] method.
  ///   * Any of the states that it depends on emits a notification.
  ///
  /// {@macro injectOptionalParameter}
  static Injected<T> injectFuture<T>(
    Future<T> Function() creator, {
    T? initialState,
    @Deprecated('Use stateInterceptor instead')
        SnapState<T>? Function(MiddleSnapState<T> middleSnap)? middleSnapState,
    SnapState<T>? Function(SnapState<T> currentSnap, SnapState<T> nextSnap)?
        stateInterceptor,
    void Function(T? s)? onInitialized,
    @Deprecated('Use sideEffects instead') void Function(T s)? onDisposed,
    @Deprecated('Use sideEffects instead') void Function()? onWaiting,
    @Deprecated('Use sideEffects instead') void Function(T s)? onData,
    // On<void>? onSetState,
    @Deprecated('Use sideEffects instead')
        void Function(dynamic e, StackTrace? s)? onError,
    SideEffects<T>? sideEffects,
    DependsOn<T>? dependsOn,
    int undoStackLength = 0,
    PersistState<T> Function()? persist,
    //
    bool isLazy = true,
    bool autoDisposeWhenNotUsed = true,
    String? debugPrintWhenNotifiedPreMessage,
    String Function(T?)? toDebugString,
  }) {
    late final InjectedImp<T> inj;
    inj = InjectedImp<T>(
      creator: creator,
      initialState: initialState,
      // onInitialized: onInitialized,
      onWaiting: onWaiting,
      onDataForSideEffect: onData,
      onError: onError,
      onDisposed: sideEffects?.dispose != null
          ? (_) => sideEffects!.dispose!()
          : onDisposed,
      onInitialized: sideEffects?.initState != null
          ? (_) => sideEffects!.initState!()
          : onInitialized,
      onSetState: On(
        () {
          sideEffects
            ?..onSetState?.call(inj.snapState)
            ..onAfterBuild?.call();
        },
      ),
      dependsOn: dependsOn,
      isAsyncInjected: true,
      undoStackLength: undoStackLength,
      persist: persist,
      middleSnapState: stateInterceptor != null
          ? (middleSnap) => stateInterceptor(
                middleSnap.currentSnap,
                middleSnap.nextSnap,
              )
          : middleSnapState,
      isLazy: isLazy,
      debugPrintWhenNotifiedPreMessage: debugPrintWhenNotifiedPreMessage,
      toDebugString: toDebugString,
      autoDisposeWhenNotUsed: autoDisposeWhenNotUsed,
    );
    return inj;
  }

  /// injection of a [Stream].
  ///
  /// ## Parameters:
  /// ### 1. creator: Required callback that returns [Stream]
  /// A callback that is used to create an instance of the injected object.
  /// It is called when:
  ///   * The state is first initialized
  ///   * The state is refreshed by calling [InjectedBase.refresh] method.
  ///   * Any of the states that it depends on emits a notification.
  ///
  /// {@macro injectOptionalParameter}
  ///   * **watch**: Object to watch its change, and do not notify listener if
  /// not changed after the stream emits data.
  static Injected<T> injectStream<T>(
    Stream<T> Function() creator, {
    T? initialState,
    @Deprecated('Use stateInterceptor instead')
        SnapState<T>? Function(MiddleSnapState<T> middleSnap)? middleSnapState,
    SnapState<T>? Function(SnapState<T> currentSnap, SnapState<T> nextSnap)?
        stateInterceptor,
    void Function(T? s, StreamSubscription subscription)? onInitialized,
    @Deprecated('Use sideEffects instead') void Function(T s)? onDisposed,
    @Deprecated('Use sideEffects instead') void Function()? onWaiting,
    @Deprecated('Use sideEffects instead') void Function(T s)? onData,
    @Deprecated('Use sideEffects instead') On<void>? onSetState,
    @Deprecated('Use sideEffects instead')
        void Function(dynamic e, StackTrace? s)? onError,
    SideEffects<T>? sideEffects,
    DependsOn<T>? dependsOn,
    PersistState<T> Function()? persist,
    int undoStackLength = 0,
    //
    bool isLazy = true,
    bool autoDisposeWhenNotUsed = true,
    String? debugPrintWhenNotifiedPreMessage,
    String Function(T?)? toDebugString,
    //
    Object? Function(T? s)? watch,
  }) {
    late final InjectedImp<T> inj;
    inj = InjectedImp<T>(
      creator: creator,
      initialState: initialState,
      // onInitialized: onInitialized != null
      //     ? (s) => onInitialized(s, inj.subscription!)
      //     : null,
      onWaiting: onWaiting,
      onDataForSideEffect: onData,
      onError: onError,
      onDisposed: sideEffects?.dispose != null
          ? (_) => sideEffects!.dispose!()
          : onDisposed,
      onInitialized: sideEffects?.initState != null
          ? (_) => sideEffects!.initState!()
          : onInitialized != null
              ? (s) => onInitialized(s, inj.subscription!)
              : null,
      onSetState: On(
        () {
          sideEffects
            ?..onSetState?.call(inj.snapState)
            ..onAfterBuild?.call();
          onSetState?.call(inj.snapState);
        },
      ),
      dependsOn: dependsOn,
      isAsyncInjected: true,
      undoStackLength: undoStackLength,
      middleSnapState: (s) {
        final SnapState<T> snap = (stateInterceptor != null
                ? stateInterceptor(
                    s.currentSnap,
                    s.nextSnap,
                  )
                : middleSnapState != null
                    ? middleSnapState(s)
                    : null) ??
            s.nextSnap;
        if (watch != null && s.currentSnap.hasData && snap.hasData) {
          final can = watch(s.currentSnap.data) == watch(snap.data);
          if (can) {
            return SkipSnapState<T>();
          }
        }
        return snap;
      },
      persist: persist,
      autoDisposeWhenNotUsed: autoDisposeWhenNotUsed,
      debugPrintWhenNotifiedPreMessage: debugPrintWhenNotifiedPreMessage,
      toDebugString: toDebugString,
    );
    if (!isLazy) {
      inj.initialize();
    }
    return inj;
  }

  ///Functional injection of a state that can authenticate and authorize
  ///a user.
  ///
  ///* Required parameters:
  ///  * **repository**:  (positional parameter) Repository that implements
  /// the IAuth<T, P> interface, where T is the Type of the user, and P is
  /// the type of the param to be used when querying the backend service.
  ///
  /// * **Optional parameters:**
  ///  * **unsignedUser**:  (named parameter) An object that represents an
  /// unsigned user. It must be of type T. It may be null.
  ///   * **param**: Default param to be used for authentication.
  /// It can be overridden when calling signUp, signIn and signOut
  /// methods
  ///   * **onSigned**: Callback to be called when a user is signed. This
  /// is the right place to navigate to a user related page.
  ///   * **onUnsigned**: Callback to be called when a user is unsigned or
  /// signed out. This is the right place to navigate to authentication page.
  ///   * **autoSignOut**: Callback that exposes the current signed user and
  /// returns a duration after which the user is automatically signed out.
  ///   * **authenticateOnInit**: Whether to authenticate the
  /// {@macro customInjectOptionalParameter}
  static InjectedAuth<T, P> injectAuth<T, P>(
    IAuth<T, P> Function() repository, {
    T? unsignedUser,
    P Function()? param,
    void Function(T s)? onSigned,
    void Function()? onUnsigned,
    Duration Function(T auth)? autoSignOut,
    FutureOr<Stream<T>> Function(IAuth<T, P> repo)? onAuthStream,
    //
    SnapState<T>? Function(MiddleSnapState<T> middleSnap)? middleSnapState,
    @Deprecated('Use sideEffects instead') void Function(T? s)? onInitialized,
    @Deprecated('Use sideEffects instead') void Function(T s)? onDisposed,
    @Deprecated('Use sideEffects instead') On<void>? onSetState,
    SideEffects<T>? sideEffects,
    //
    PersistState<T> Function()? persist,
    String? debugPrintWhenNotifiedPreMessage,
    String Function(T?)? toDebugString,
  }) {
    assert(
      null is T || unsignedUser != null,
      '$T is non nullable, you have to define unsignedUser parameter.\n'
      'If you want the unsignedUSer to be null use nullable type ($T?)',
    );
    assert(
      null is! T || unsignedUser == null,
      'Because $T is nullable, null is considered as the unsigned user.'
      'You can not set a non null unsignedUser\n'
      'If you want the unsignedUSer to be non null use non nullable type ($T).',
    );
    late final InjectedAuthImp<T, P> inj;
    inj = InjectedAuthImp<T, P>(
      repoCreator: repository,
      unsignedUser: unsignedUser,
      param: param,
      onSigned: onSigned,
      onUnsigned: onUnsigned,
      autoSignOut: autoSignOut,
      onAuthStream: onAuthStream,
      //
      middleSnapState: middleSnapState,
      sideEffects: SideEffects<T>(
        initState: () {
          if (sideEffects?.initState != null) {
            sideEffects?.initState?.call();
          } else {
            onInitialized?.call(inj.state);
          }
        },
        onSetState: (snap) {
          if (sideEffects?.onSetState != null) {
            sideEffects?.onSetState?.call(snap);
          } else {
            onSetState?.call(snap);
          }
        },
        dispose: () {
          if (sideEffects?.dispose != null) {
            sideEffects?.dispose?.call();
          } else {
            onDisposed?.call(inj.state);
          }
        },
      ),
      //
      persist: persist,
      debugPrintWhenNotifiedPreMessage: debugPrintWhenNotifiedPreMessage,
      toDebugString: toDebugString,
    );
    return inj;
  }

  ///Functional injection of a state that can create, read, update and
  ///delete from a backend or database service.
  ///
  ///* Required parameters:
  ///  * **repository**:  (positional parameter) Repository that implements
  /// the ICRUD<T,P> interface, where T is the Type of the state, and P is
  /// the type of the param to be used when querying the backend service.
  ///
  /// * **Optional parameters:**
  ///   * **param**: Default param to be used when querying the database.
  /// It can be overridden when calling create, read, update and delete
  /// methods
  ///   * **readOnInitialization**: If true a read query with the default
  /// param will se sent to the backend service once the state is initialized.
  /// You can set it to false and intentionally call read method the time you
  /// want.
  /// {@template customInjectOptionalParameter}
  ///   * **sideEffects**: used to handle sideEffects. It takes a [SideEffects]
  /// object.
  ///   * **dependsOn**: The other [Injected] models this Injected depends on.
  /// It takes an instance of [DependsOn] object.
  ///   * **undoStackLength**: the length of the undo/redo stack. If not
  /// defined, the undo/redo is disabled.
  ///   * **persist**: If defined the state of this Injected will be persisted.
  /// It takes A callback that returns an instance of [PersistState].
  ///   * **autoDisposeWhenNotUsed**: Whether to auto dispose the injected
  /// model when no longer used (listened to).
  /// The default value is true.
  ///   * **isLazy**: By default models are lazily injected; that is not
  /// instantiated until first used.
  ///   * **debugPrintWhenNotifiedPreMessage**: if not null, print an
  /// informative message when this model is notified in the debug mode. The
  /// entered message will pré-append the debug message. Useful if the type of
  /// the injected model is primitive to distinguish
  /// {@endtemplate}
  static InjectedCRUD<T, P> injectCRUD<T, P>(
    ICRUD<T, P> Function() repository, {
    P Function()? param,
    bool readOnInitialization = false,
    OnCRUD<void>? onCRUD,
    //
    SnapState<List<T>>? Function(MiddleSnapState<List<T>> middleSnap)?
        middleSnapState,
    @Deprecated('Use sideEffects instead')
        void Function(List<T>? s)? onInitialized,
    @Deprecated('Use sideEffects instead') void Function(List<T> s)? onDisposed,
    @Deprecated('Use sideEffects instead') On<void>? onSetState,
    SideEffects<List<T>>? sideEffects,
    //
    DependsOn<List<T>>? dependsOn,
    int undoStackLength = 0,
    PersistState<List<T>> Function()? persist,
    //
    bool autoDisposeWhenNotUsed = true,
    bool isLazy = true,
    String? debugPrintWhenNotifiedPreMessage,
    String Function(List<T>?)? toDebugString,
  }) {
    late final InjectedCRUDImp<T, P> inj;
    inj = InjectedCRUDImp<T, P>(
      repoCreator: repository,
      param: param,
      readOnInitialization: readOnInitialization,
      onCRUD: onCRUD,
      //
      middleSnapState: middleSnapState,
      onInitialized: sideEffects?.initState != null
          ? (_) => sideEffects!.initState!()
          : onInitialized,
      onDisposed: sideEffects?.dispose != null
          ? (_) => sideEffects!.dispose!()
          : onDisposed,
      onSetState: On(
        () {
          if (sideEffects?.onSetState != null) {
            sideEffects!.onSetState!(inj.snapState);
          } else {
            onSetState?.call(inj.snapState);
          }
          sideEffects?.onAfterBuild?.call();
        },
      ),

      //
      dependsOn: dependsOn,
      undoStackLength: undoStackLength,
      persist: persist,
      autoDisposeWhenNotUsed: autoDisposeWhenNotUsed,
      debugPrintWhenNotifiedPreMessage: debugPrintWhenNotifiedPreMessage,
      toDebugString: toDebugString,
    );
    return inj;
  }

  ///{@template injectedTheme}
  ///Functional injection of a state that handle app theme switching.
  ///
  ///* Required parameters:
  ///  * **lightThemes**:  Map of light themes the app supports. The keys of
  /// the Map are the names of the themes. They can be String or enumeration
  ///
  /// * **Optional parameters:**
  ///  * **darkThemes**:  Map of dark themes the app supports. There should
  /// be a correspondence between light and dark themes. Nevertheless, you
  /// can have light themes with no corresponding dark one.
  ///  * **themeMode**: the theme Mode the app should start with.
  ///  * **persistKey**: If defined the app theme is persisted to a local
  /// storage. The persisted theme will be used on app restarting.
  /// {@endtemplate}
  /// {@macro customInjectOptionalParameter}
  static InjectedTheme<KEY> injectTheme<KEY>({
    required Map<KEY, ThemeData> lightThemes,
    Map<KEY, ThemeData>? darkThemes,
    ThemeMode themeMode = ThemeMode.system,
    String? persistKey,
    //
    SnapState<KEY>? Function(MiddleSnapState<KEY> middleSnap)? middleSnapState,
    @Deprecated('Use sideEffects instead') void Function(KEY? s)? onInitialized,
    @Deprecated('Use sideEffects instead') void Function(KEY s)? onDisposed,
    @Deprecated('Use sideEffects instead') On<void>? onSetState,
    SideEffects<KEY>? sideEffects,
    //
    DependsOn<KEY>? dependsOn,
    int undoStackLength = 0,
    //
    bool autoDisposeWhenNotUsed = true,
    bool isLazy = true,
    String? debugPrintWhenNotifiedPreMessage,
    String Function(KEY?)? toDebugString,
  }) {
    assert(
      KEY != dynamic && KEY != Object,
      'Type can not inferred, please declare it explicitly',
    );
    late final InjectedThemeImp<KEY> inj;
    inj = InjectedThemeImp<KEY>(
      lightThemes: lightThemes,
      darkThemes: darkThemes,
      themeModel: themeMode,
      persistKey: persistKey,
      //
      middleSnapState: middleSnapState,
      onInitialized: sideEffects?.initState != null
          ? (_) => sideEffects!.initState!()
          : onInitialized,
      onDisposed: sideEffects?.dispose != null
          ? (_) => sideEffects!.dispose!()
          : onDisposed,
      onSetState: On(
        () {
          if (sideEffects?.onSetState != null) {
            sideEffects!.onSetState!(inj.snapState);
          } else {
            onSetState?.call(inj.snapState);
          }
          sideEffects?.onAfterBuild?.call();
        },
      ),
      //
      dependsOn: dependsOn,
      undoStackLength: undoStackLength,
      //
      autoDisposeWhenNotUsed: autoDisposeWhenNotUsed,
      isLazy: isLazy,
      debugPrintWhenNotifiedPreMessage: debugPrintWhenNotifiedPreMessage,
      toDebugString: toDebugString,
    );
    return inj;
  }

  ///Functional injection of a state that handle app internationalization
  ///and localization.
  ///
  ///* Required parameters:
  ///  * **i18n**:  Map of supported locales with their language translation.
  ///
  /// * **Optional parameters:**
  ///  * **persistKey**: If defined the app locale is persisted to a local
  /// storage. On app start, the stored locale will be used.
  /// {@macro customInjectOptionalParameter}
  static InjectedI18N<I18N> injectI18N<I18N>(
    Map<Locale, FutureOr<I18N> Function()> i18Ns, {
    String? persistKey,
    //
    SnapState<I18N>? Function(MiddleSnapState<I18N> middleSnap)?
        middleSnapState,
    @Deprecated('Use sideEffects instead')
        void Function(I18N? s)? onInitialized,
    @Deprecated('Use sideEffects instead') void Function(I18N s)? onDisposed,
    @Deprecated('Use sideEffects instead') On<void>? onSetState,
    SideEffects<I18N>? sideEffects,
    //
    DependsOn<I18N>? dependsOn,
    int undoStackLength = 0,
    //
    // bool isLazy = true,
    String? debugPrintWhenNotifiedPreMessage,
  }) {
    assert(
      I18N != dynamic && I18N != Object,
      'Type can not inferred, please declare it explicitly',
    );
    late final InjectedI18NImp<I18N> inj;
    inj = InjectedI18NImp<I18N>(
      i18Ns: i18Ns,
      persistKey: persistKey,
      //
      middleSnapState: middleSnapState,
      onInitialized: sideEffects?.initState != null
          ? (_) => sideEffects!.initState!()
          : onInitialized,
      onDisposed: sideEffects?.dispose != null
          ? (_) => sideEffects!.dispose!()
          : onDisposed,
      onSetState: On(
        () {
          if (sideEffects?.onSetState != null) {
            sideEffects!.onSetState!(inj.snapState);
          } else {
            onSetState?.call(inj.snapState);
          }
          sideEffects?.onAfterBuild?.call();
        },
      ),
      //
      dependsOn: dependsOn,
      undoStackLength: undoStackLength,
      //
      // isLazy: isLazy,
      debugPrintWhenNotifiedPreMessage: debugPrintWhenNotifiedPreMessage,
    );
    return inj;
  }

  ///Inject an animation. It works for both implicit and explicit animation.
  ///
  ///Animation is auto disposed if no longer used.
  ///
  ///* **duration** Animation duration, It is required.
  ///* **reverseDuration** The length of time this animation should last when going in reverse.
  ///* **curve** Animation curve, It defaults to Curves.linear
  ///* **reverseCurve** Animation curve to be used when the animation is going in reverse.
  ///* **initialValue** The AnimationController's value the animation start with.
  ///* **lowerBound** The value at which this animation is deemed to be dismissed.
  ///* **upperBound** The value at which this animation is deemed to be completed.
  ///* **animationBehavior** he behavior of the controller when [AccessibilityFeatures.disableAnimations]
  /// is true.
  ///* **repeats** the number of times the animation repeats (always from start to end).
  ///A value of zero means that the animation will repeats infinity.
  ///* **shouldReverseRepeats** When it is set to true, animation will repeat by alternating
  ///between begin and end on each repeat.
  ///* **shouldAutoStart** When it is set to true, animation will auto start after first initialized.
  ///* **endAnimationListener** callback to be fired after animation ends (After purge of repeats and cycle)
  ///
  ///See [OnAnimationBuilder]
  ///
  ///Example of Implicit Animated Container
  ///
  ///```dart
  /// final animation = RM.injectAnimation(
  ///   duration: Duration(seconds: 2),
  ///   curve: Curves.fastOutSlowIn,
  /// );
  ///
  /// class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  ///   bool selected = false;
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return GestureDetector(
  ///       onTap: () {
  ///         setState(() {
  ///           selected = !selected;
  ///         });
  ///       },
  ///       child: Center(
  ///         child: OnAnimationBuilder(
  ///           listenTo: animation,
  ///           builder: (animate) {
  ///             final width = animate(selected ? 200.0 : 100.0);
  ///             final height = animate(selected ? 100.0 : 200.0, 'height');
  ///             final alignment = animate(
  ///               selected ? Alignment.center : AlignmentDirectional.topCenter,
  ///             );
  ///             final Color? color = animate(
  ///               selected ? Colors.red : Colors.blue,
  ///             );
  ///             return Container(
  ///               width: width,
  ///               height: height,
  ///               color: color,
  ///               alignment: alignment,
  ///               child: const FlutterLogo(size: 75),
  ///             );
  ///           },
  ///         ),
  ///       ),
  ///     );
  ///   }
  /// }
  ///````
  static InjectedAnimation injectAnimation({
    required Duration duration,
    Duration? reverseDuration,
    Curve curve = Curves.linear,
    Curve? reverseCurve,
    double? initialValue,
    double lowerBound = 0.0,
    double upperBound = 1.0,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
    int? repeats,
    bool shouldReverseRepeats = false,
    bool shouldAutoStart = false,
    void Function(InjectedAnimation)? onInitialized,
    void Function()? endAnimationListener,
  }) {
    return InjectedAnimationImp(
      duration: duration,
      reverseDuration: reverseDuration,
      curve: curve,
      reverseCurve: reverseCurve,
      lowerBound: lowerBound,
      upperBound: upperBound,
      animationBehavior: animationBehavior,
      repeats: repeats,
      shouldReverseRepeats: shouldReverseRepeats,
      shouldAutoStart: shouldAutoStart,
      onInitialized: onInitialized,
      endAnimationListener: endAnimationListener,
      initialValue: initialValue,
    );
  }

  ///Inject a TextEditingController
  ///
  ///* **text** is the initial text.
  ///* **selection** the initial text selection
  ///* **composing** is initial the range of text.
  ///* **validator** used for input validation, If it returns null means input
  ///is valid, else the return string is the error message.
  ///* **validateOnTyping** if set to true the input text is validated while typing.
  ///Default value is true.
  ///* **validateOnLoseFocus** if set to true the input text is validated just
  ///after the field lose focus.
  ///* **onTextEditing** fired whenever the input text or selection changes
  ///* **autoDispose** if set to true the InjectedTextEditing is disposed of when
  ///no longer used.
  static InjectedTextEditing injectTextEditing({
    String text = '',
    TextSelection selection = const TextSelection.collapsed(offset: -1),
    TextRange composing = TextRange.empty,
    @Deprecated('Use validators instead')
        String? Function(String? text)? validator,
    List<String? Function(String? text)>? validators,
    bool? validateOnTyping,
    bool? validateOnLoseFocus,
    void Function(InjectedTextEditing textEditing)? onTextEditing,
    bool autoDispose = true,
  }) {
    return InjectedTextEditingImp(
      text: text,
      selection: selection,
      composing: composing,
      validator: validators ?? (validator != null ? [validator] : null),
      validateOnTyping: validateOnTyping,
      validateOnLoseFocus: validateOnLoseFocus,
      autoDispose: autoDispose,
      onTextEditing: onTextEditing,
    );
  }

  ///Inject a form.
  ///
  ///* **autoFocusOnFirstError** : After the form is validate, get focused on
  ///the first non valid TextField, if any.
  ///* **submit** : Contains the user submission logic. Called when invoking
  ///[InjectedForm.submit] method.
  ///* **onSubmitting** : Callback called while waiting for form submission.
  ///* **onSubmitted** : Callback called if the form successfully submitted.
  static InjectedForm injectForm({
    AutovalidateMode autovalidateMode = AutovalidateMode.disabled,
    bool autoFocusOnFirstError = true,
    void Function()? onSubmitting,
    void Function()? onSubmitted,
    Future<void> Function()? submit,
    // void Function(dynamic, void Function())? onSubmissionError,
  }) {
    return InjectedFormImp(
      autovalidateMode: autovalidateMode,
      autoFocusOnFirstError: autoFocusOnFirstError,
      onSubmitting: onSubmitting,
      onSubmitted: onSubmitted,
      submit: submit,
    );
  }

  ///Inject a TextEditingController
  ///
  ///* **initialValue** is the initial value.
  ///* **validators** used for input validation, If it returns null means input
  ///is valid, else the return string is the error message.
  ///* **onValueChange** if set to true the input is validated while changing.
  ///Default value is true.
  ///* **validateOnLoseFocus** if set to true the input text is validated just
  ///after the field lose focus.
  ///* **onValueChange** fired whenever the input value is changed
  ///* **autoDispose** if set to true the InjectedTextEditing is disposed of when
  ///no longer used.S
  static InjectedFormField<T> injectFormField<T>(
    T initialValue, {
    List<String? Function(T value)>? validators,
    bool? validateOnValueChange,
    bool? validateOnLoseFocus,
    void Function(InjectedFormField formField)? onValueChange,
    bool autoDispose = true,
  }) {
    return InjectedFormFieldImp<T>(
      initialValue,
      validator: validators,
      validateOnValueChange: validateOnValueChange,
      validateOnLoseFocus: validateOnLoseFocus,
      autoDispose: autoDispose,
      onValueChange: onValueChange,
    );
  }

  ///Inject a ScrollController
  ///
  ///* **initialScrollOffset** is the initial scroll offset
  ///* **keepScrollOffset** similar to [ScrollController.keepScrollOffset]
  ///* **onScrolling: a callback invoked each time the ScrollController emits a
  ///notification.
  ///* **endScrollDelay** The delay in milliseconds to be awaited after the user stop scrolling to
  ///consider scrolling action ended.
  static InjectedScrolling injectScrolling({
    double initialScrollOffset = 0.0,
    bool keepScrollOffset = true,
    void Function(InjectedScrolling)? onScrolling,
    int endScrollDelay = 300,
  }) {
    return InjectedScrollingImp(
      initialScrollOffset: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      onScroll: onScrolling != null ? OnScroll<void>(onScrolling) : null,
      onScrollEndedDelay: endScrollDelay,
    );
  }

  ///Injected a PageController and/or a TabController
  ///
  ///It combines both controller to use the best of them.
  ///
  ///* **initialIndex** The initial index the app start with.
  ///
  ///* **length** The total number of tabs
  ///Typically greater than one. Must match [TabBar.tabs]'s and
  ///[TabBarView.children]'s length.
  ///
  ///* **duration** The duration the page/tab transition takes. Defaults to
  ///Duration(milliseconds: 300)
  ///
  ///* **curve** The curve the page/tab animation transition takes. Defaults to
  ///Curves.ease
  ///
  ///* **keepPage** Save the current [page] with [PageStorage] and restore it if this
  ///controller's scrollable is recreated. See [PageController.keepPage]
  ///
  ///* **viewportFraction** The fraction of the viewport that each page should occupy.
  ///Defaults to 1.0, which means each page fills the viewport in the
  ///scrolling direction. See [PageController.viewportFraction]
  static InjectedPageTab injectPageTab({
    int initialIndex = 0,
    required int length,
    Duration duration = kTabScrollDuration,
    Curve curve = Curves.ease,
    bool keepPage = true,
    double viewportFraction = 1.0,
  }) {
    return InjectedTabImp(
      initialIndex: initialIndex,
      length: length,
      curve: curve,
      duration: duration,
      keepPage: keepPage,
      viewportFraction: viewportFraction,
    );
  }

  ///Static variable the holds the chosen working environment or flavour.
  static dynamic env;
  static int? _envMapLength;

  ///Functional injection of flavors (environments).
  ///
  ///* Required parameters:
  ///  * [impl]:  (positional parameter) Map of the implementations of the interface.
  /// * optional parameters:
  /// {@macro injectOptionalParameter}
  static Injected<T> injectFlavor<T>(
    Map<dynamic, FutureOr<T> Function()> impl, {
    T? initialState,
    SnapState<T>? Function(MiddleSnapState<T> middleSnap)? middleSnapState,
    void Function(T? s)? onInitialized,
    @Deprecated('Use sideEffects instead') void Function(T s)? onDisposed,
    @Deprecated('Use sideEffects instead') void Function()? onWaiting,
    @Deprecated('Use sideEffects instead') void Function(T s)? onData,
    @Deprecated('Use sideEffects instead') On<void>? onSetState,
    @Deprecated('Use sideEffects instead')
        void Function(dynamic e, StackTrace? s)? onError,
    SideEffects<T>? sideEffects,

    //
    DependsOn<T>? dependsOn,
    int undoStackLength = 0,
    PersistState<T> Function()? persist,
    //
    bool autoDisposeWhenNotUsed = true,
    bool isLazy = true,
    String? debugPrintWhenNotifiedPreMessage,
    String Function(T?)? toDebugString,
  }) {
    late final InjectedImp<T> inj;
    inj = InjectedImp<T>(
      creator: () {
        _envMapLength ??= impl.length;
        assert(RM.env != null, '''
You are using [RM.injectFlavor]. You have to define the [RM.env] before the [runApp] method
    ''');
        assert(impl[env] != null, '''
There is no implementation for $env of $T interface
    ''');
        assert(impl.length == _envMapLength, '''
You must be consistent about the number of flavor environment you have.
you had $_envMapLength flavors and you are defining ${impl.length} flavors.
    ''');
        return impl[env]!();
      },
      initialState: initialState,
      autoDisposeWhenNotUsed: autoDisposeWhenNotUsed,

      onDisposed: sideEffects?.dispose != null
          ? (_) => sideEffects!.dispose!()
          : onDisposed,
      onInitialized: sideEffects?.initState != null
          ? (_) => sideEffects!.initState!()
          : onInitialized != null
              ? (s) => onInitialized(s)
              : null,
      onSetState: On(
        () {
          sideEffects
            ?..onSetState?.call(inj.snapState)
            ..onAfterBuild?.call();
          onSetState?.call(inj.snapState);
        },
      ),

      onDataForSideEffect: onData,
      onError: onError,
      onWaiting: onWaiting,

      // watch: watch,
      dependsOn: dependsOn,
      undoStackLength: undoStackLength,
      persist: persist,
      debugPrintWhenNotifiedPreMessage: debugPrintWhenNotifiedPreMessage,
      toDebugString: toDebugString,
      middleSnapState: middleSnapState,
      isLazy: isLazy,
    );
    return inj;
  }

  ///Initialize the default persistance provider to be used.
  ///
  ///Called in the main method:
  ///```dart
  ///void main()async{
  /// WidgetsFlutterBinding.ensureInitialized();
  ///
  /// await RM.storageInitializer(IPersistStoreImp());
  /// runApp(MyApp());
  ///}
  ///
  ///```
  ///
  ///This is considered as the default storage provider. It can be overridden
  ///with [PersistState.persistStateProvider]
  ///
  ///For test use [RM.storageInitializerMock].
  static Future<void> storageInitializer(IPersistStore store) async {
    if (_persistStateGlobal != null || _persistStateGlobalTest != null) {
      return;
    }
    _persistStateGlobal = store;
    return _persistStateGlobal?.init();
  }

  ///Initialize a mock persistance provider.
  ///
  ///Used for tests.
  ///
  ///It is wise to clear the store in setUp method, to ensure a fresh store for each test
  ///```dart
  /// setUp(() {
  ///  storage.clear();
  /// });
  ///```
  static Future<_PersistStoreMock> storageInitializerMock() async {
    _persistStateGlobalTest = _PersistStoreMock();
    await _persistStateGlobalTest?.init();
    return (_persistStateGlobalTest as _PersistStoreMock);
  }

  static Future<void> deleteAllPersistState() async {
    await (_persistStateGlobalTest ?? _persistStateGlobal)?.deleteAll();
    UndoRedoPersistState.cleanStorageProviders();
  }

  static void disposeAll() {
    for (var inj in [...injectedModels]) {
      inj.dispose();
    }
    injectedModels.clear();
    _scaffold._dispose();
    _navigate._dispose();
  }

  static _Scaffold scaffold = _scaffold;
  static _Navigate navigate = _navigate;
  static _Transitions transitions = _transitions;
  static BuildContext? _context;

  ///Get an active [BuildContext].
  ///
  ///The obtained [BuildContext] is one of the [states_rebuilder]'s widgets
  ///context;
  ///
  ///For this reason you have to use at least one of [states_rebuilder]'s widgets.
  static BuildContext? get context {
    if (_context != null) {
      return _context;
    }

    if (_contextSet.isNotEmpty) {
      if (_contextSet.last.findRenderObject()?.attached != true) {
        _contextSet.removeLast();
        // ignore: recursive_getters
        return context;
      }
      return _contextSet.last;
    }

    return RM.navigate._navigatorKey.currentState?.context;
  }

  // static set context(BuildContext? context) {
  //   if (context == null) {
  //     return;
  //   }
  //   _context = context;
  //   WidgetsBinding.instance?.addPostFrameCallback(
  //     (_) {
  //       return _context = null;
  //     },
  //   );
  // }

  //
  static ReactiveModel<T> get<T>([String? name]) {
    return Injector.getAsReactive<T>(name: name);
  }
}

final injectedModels = <InjectedBaseState<dynamic>>{};
VoidCallback addToInjectedModels(InjectedBaseState<dynamic> inj) {
  injectedModels.add(inj);

  return () {
    injectedModels.remove(inj);
  };
}

final List<BuildContext> _contextSet = [];

VoidCallback addToContextSet(BuildContext ctx) {
  _contextSet.add(ctx);
  // print('contextSet length is ${_contextSet.length}');
  return () {
    _contextSet.remove(ctx);
    // print('contextSet dispose length is ${_contextSet.length}');
  };
}
