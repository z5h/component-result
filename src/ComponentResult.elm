module ComponentResult exposing
    ( ComponentResult
    , withModel, justError
    , withCmd, withCmds, withExternalMsg
    , mapError, mapModel, mapMsg
    , map2Model, applyExternalMsg, sequence
    , resolve, resolveError
    , escape
    )

{-| This library helps move data between components, where

A Component is a `model` that can be initialized, and updated.
In addition to returning a `model` from `init` or `update`, a component can

  - optionally dispatch a `Cmd msg`
  - optionally return an `externalMsg` for the parent/caller to use.

Importantly, a component's `init`/`update` may instead return just an `error` , and let the parent/caller decide how to deal with it.

This is most helpful in large apps where you have constructs like "sub-pages" and component-style
modules (i.e. having model + init + update + view).

The purpose of this library is to standardize boilerplate within one's app,
not necessarily to reduce it.


# Definition

@docs ComponentResult


# Creating

@docs withModel, justError


# Augmenting

Add Cmds and external messages to a ComponentResult.

@docs withCmd, withCmds, withExternalMsg


# Basic Mapping

Transform the `model`, `error`, or `(Cmd) msg` of a ComponentResult.

@docs mapError, mapModel, mapMsg


# Advanced

@docs map2Model, applyExternalMsg, sequence


# Consuming

@docs resolve, resolveError


# Other

@docs escape

-}


{-| A ComponentResult is an encapsulation of the typicall results of updating a component.
It can represent model state, as well as dispatched `Cmd msg`, external messages and errors.
-}
type ComponentResult model msg externalMsg err
    = ModelAndCmd model (Cmd msg)
    | ModelAndExternal model externalMsg (Cmd msg)
    | JustError err


{-| At minimum, a non-error-state ComponentResult must always have a model.
This creates a ComponentResult with a model.

Use [`withCmd`](#withCmd), [`withExternalMsg`](#withExternalMsg), etc, to augment.

-}
withModel : model -> ComponentResult model msg externalMsg err
withModel model =
    ModelAndCmd model Cmd.none


{-| An error-state ComponentResult may be created with an error parameter.
Note that `withCmd`, `withExternalMsg` etc have no effect on an error-state component result.
-}
justError : err -> ComponentResult model msg externalMsg err
justError =
    JustError


{-| Add a `Cmd msg` to a `ComponentResult`. This is a noop for error-state `ComponentResult`.
Batches cmd with any existing ones.

    withModel myModel
        |> withCmd myHttpGet
        |> withCmd myPortCmd

-}
withCmd : Cmd msg -> ComponentResult model msg externalMsg err -> ComponentResult model msg externalMsg err
withCmd cmd result =
    case result of
        ModelAndCmd model cmd0 ->
            ModelAndCmd model (Cmd.batch [ cmd0, cmd ])

        ModelAndExternal model externalMsg cmd0 ->
            ModelAndExternal model externalMsg (Cmd.batch [ cmd0, cmd ])

        JustError err ->
            JustError err


{-| Add a list of `Cmd msg` to a `ComponentResult`. This is a noop for error-state `ComponentResult`.
Batches cmd with any existing ones.

    withModel myModel
        |> withCmds myHttpGets
        |> withCmds myPortCmds

-}
withCmds : List (Cmd msg) -> ComponentResult model msg externalMsg err -> ComponentResult model msg externalMsg err
withCmds cmds result =
    case cmds of
        [] ->
            result

        _ ->
            withCmd (Cmd.batch cmds) result


{-| Add an external message (intended for the caller to interpret) to a `ComponentResult` which
does not yet have an external message. This is a noop for error-state `ComponentResult`.

    withModel myModel
        |> withCmd myHttpGet
        |> withExternalMsg LoadingData

-}
withExternalMsg : externalMsg -> ComponentResult model msg Never err -> ComponentResult model msg externalMsg err
withExternalMsg externalMsg result =
    case result of
        ModelAndCmd model cmd ->
            ModelAndExternal model externalMsg cmd

        ModelAndExternal model aNever cmd ->
            never aNever

        JustError err ->
            JustError err


{-| Transform a `ComponentResult`'s model, if it exists (i.e. it is not a [`justError`](#justError)).
Typical usage:

    update : Msg -> Model -> ComponentResult Msg Model externMsg err
    update msg model =
        case msg of
            PageMsg pageMsg ->
                Page.update pageMsg model.pageModel
                    |> ComponentResult.mapModel (\newPageModel -> { model | pageModel = newPageModel })
                    |> ComponentResult.mapCmd PageMsg

-}
mapModel : (model -> newModel) -> ComponentResult model msg externalMsg err -> ComponentResult newModel msg externalMsg err
mapModel f result =
    case result of
        ModelAndCmd model cmd ->
            ModelAndCmd (f model) cmd

        ModelAndExternal model externalMsg cmd ->
            ModelAndExternal (f model) externalMsg cmd

        JustError err ->
            JustError err


{-| Transform a `ComponentResult`'s cmds, if it has any.
Typical usage:

    update : Msg -> Model -> ComponentResult Msg Model externMsg err
    update msg model =
        case msg of
            PageMsg pageMsg ->
                Page.update pageMsg model.pageModel
                    |> ComponentResult.mapModel (\newPageModel -> { model | pageModel = newPageModel })
                    |> ComponentResult.mapCmd PageMsg

-}
mapMsg : (msg -> newMsg) -> ComponentResult model msg externalMsg err -> ComponentResult model newMsg externalMsg err
mapMsg f result =
    case result of
        ModelAndCmd model cmd ->
            ModelAndCmd model (Cmd.map f cmd)

        ModelAndExternal model externalMsg cmd ->
            ModelAndExternal model externalMsg (Cmd.map f cmd)

        JustError err ->
            JustError err


{-| Transform a `ComponentResult`'s error value, if it is in an error state.
-}
mapError : (err -> newErr) -> ComponentResult model msg externalMsg err -> ComponentResult model msg externalMsg newErr
mapError f result =
    case result of
        ModelAndCmd model msgCmd ->
            ModelAndCmd model msgCmd

        ModelAndExternal model externalMsg msgCmd ->
            ModelAndExternal model externalMsg msgCmd

        JustError err ->
            JustError (f err)


{-| Given a function to map 2 models into a new model, and 2 ComponentResults with such models,
map the ComponentResults into a new one, maintinaing error state, if any, and batching `Cmd msg`
if any.

    init : ComponentResult Model Cmd externalMsg err
    init =
        map2Model (\modelA modelB -> { a = modelA, b = modelB , sort = Default, ...})
            (SubComponentA.init |> ComponentResult.mapCmd ComponentACmd)
            (SubComponentB.init |> ComponentResult.mapCmd ComponentBCmd)

-}
map2Model :
    (model1 -> model2 -> newModel)
    -> ComponentResult model1 msg externalMsg err
    -> ComponentResult model2 msg Never err
    -> ComponentResult newModel msg externalMsg err
map2Model f result1 result2 =
    case ( result1, result2 ) of
        ( ModelAndCmd model1 cmd1, ModelAndCmd model2 cmd2 ) ->
            ModelAndCmd (f model1 model2) (Cmd.batch [ cmd1, cmd2 ])

        ( ModelAndExternal model1 external1 cmd1, ModelAndCmd model2 cmd2 ) ->
            ModelAndExternal (f model1 model2) external1 (Cmd.batch [ cmd1, cmd2 ])

        ( _, ModelAndExternal _ aNever _ ) ->
            never aNever

        ( JustError err, _ ) ->
            JustError err

        ( _, JustError err ) ->
            JustError err


{-| Sequence several `ComponentResult` returning operations. E.g. suppose we need to
initialize a model and immediately update it as well:

    DataStore.init credentials
        |> sequence
            [ \model -> DataStore.update (DataStore.DeleteUserPosts user) model
            , \model -> DataStore.update (DataStore.DeleteUser user) model
            ]

NOTE: Elm docs say "there are no ordering guarantees" for batched Cmds and the same is true here.
`update` calls are processed in sequence but the resulting batched commands are not.

-}
sequence : List (model -> ComponentResult model msg Never err) -> ComponentResult model msg Never err -> ComponentResult model msg neverExternalMsg err
sequence updaters componentResult =
    List.foldl
        (\updater result ->
            case result of
                ModelAndCmd model_ cmd ->
                    updater model_ |> withCmd cmd

                ModelAndExternal _ aNever _ ->
                    never aNever

                JustError err ->
                    JustError err
        )
        componentResult
        updaters
        |> (\result ->
                case result of
                    ModelAndCmd model_ cmd ->
                        ModelAndCmd model_ cmd

                    ModelAndExternal _ aNever _ ->
                        never aNever

                    JustError err ->
                        JustError err
           )


{-| Apply the internal externalMsg (if any).
The caller therefore has the opportuinity to remove the bound externalMsg type
(and optionally replace it).

In general, the idea is that the caller is an `update` function calling into another (sub-component's)
`update` function. The caller will get back a `ComponentResult` and needs to transform that
into the `ComponentResult` it will return to it's caller.

An `externalMsg` is used to inform the caller that it may need to augment it's processing.
e.g.

    update : Msg -> Model -> ComponentResult Model Msg externalMsg err
    update model msg =
        case ( msg, pageModel ) of
            ( AccountPageMsg pageMsg, AccountPageModel pageModel ) ->
                AccountPage.update pageMsg pageModel
                    |> ComponentResult.mapModel (\newPageModel -> { model | pageModel = AccountPageModel newPageModel })
                    |> ComponentResult.mapCmd AccountPageMsg
                    |> ComponentResult.applyExternalMsg
                        (\externalMsg result ->
                            case externalMsg of
                                AccountPage.LoggedOut ->
                                    result
                                        |> ComponentResult.withCmd (Ports.logout ())
                        )

-}
applyExternalMsg :
    (externalMsg
     -> ComponentResult model msg never err
     -> ComponentResult model msg newExternalMessage err
    )
    -> ComponentResult model msg externalMsg err
    -> ComponentResult model msg newExternalMessage err
applyExternalMsg f result =
    case result of
        ModelAndCmd model msgCmd ->
            ModelAndCmd model msgCmd

        ModelAndExternal model externalMsg msgCmd ->
            f externalMsg (ModelAndCmd model msgCmd)

        JustError err ->
            JustError err


{-| Discard the externalMsg of a `ComponentResult` (if one is present).
-}
discardExternalMsg : ComponentResult model msg externalMsg err -> ComponentResult model msg neverExternalMsg err
discardExternalMsg componentResult =
    case componentResult of
        ModelAndCmd model msgCmd ->
            ModelAndCmd model msgCmd

        ModelAndExternal model externalMsg msgCmd ->
            ModelAndCmd model msgCmd

        JustError err ->
            JustError err


{-| Provided a function that can map an error to a non-error-state ComponentResult,
we can accept any `ComponentResult` and guarantee a return of a non-error `ComponentResult`.
-}
resolveError : (err -> ComponentResult model msg externalMsg Never) -> ComponentResult model msg externalMsg err -> ComponentResult model msg externalMsg never
resolveError f result =
    case result of
        ModelAndCmd model cmd ->
            ModelAndCmd model cmd

        ModelAndExternal model externalMsg cmd ->
            ModelAndExternal model externalMsg cmd

        JustError err ->
            f err |> mapError never


{-| Given a non-error `ComponentResult` with no external message, transorfm it into the familiar
`( model, Cmd msg )` type.

This is useful at the top-level `update` function, because the Browser package
requires a return of ( model, Cmd msg ).

-}
resolve : ComponentResult model msg Never Never -> ( model, Cmd msg )
resolve result =
    case result of
        ModelAndCmd model cmd ->
            ( model, cmd )

        ModelAndExternal _ aNever _ ->
            never aNever

        JustError aNever ->
            never aNever


{-| "Escape" out of the `ComponentResult` format, and into Core Elm types.
Doing this loses the benifits of the `ComponentResult` type and related functions.

This shouldn't typically be required in production, but might be handy for debugging/testing/prototyping.

-}
escape : ComponentResult model msg externalMsg err -> Result err ( model, Cmd msg, Maybe externalMsg )
escape componentResult =
    case componentResult of
        ModelAndCmd model cmd ->
            Result.Ok ( model, cmd, Nothing )

        ModelAndExternal model externalMsg cmd ->
            Result.Ok ( model, cmd, Just externalMsg )

        JustError err ->
            Result.Err err
