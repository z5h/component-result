module ComponentResult exposing
    ( ComponentResult
    , withModel, justError
    , withCmd, withCmds, withExternalMsg
    , mapError, mapModel, mapMsg
    , map2Model, applyExternalMsg, sequence
    , resolve, resolveError, resolveModel
    )

{-| This library helps move data between components, where a component is something that

1.  has a model,
2.  has operations which
    1.  may update the model,
    2.  may also dispatch commands,
    3.  may also return a value for the caller,
    4.  may instead result in an error.

This is most helpful in large apps where you have constructs like "sub-pages" and component-style
modules (i.e. having model + init + update + view).

The purpose of this library is to **standardize** boilerplate within one's app,
not necessarily to reduce it.


# Definition

@docs ComponentResult


# Creating

@docs withModel, justError


# Augmenting

Add Cmds and external messages to a ComponentResult.

@docs withCmd, withCmds, withExternalMsg


# Basic Mapping

Use transform the model, error, or (Cmd) msg of a ComponentResult.

@docs mapError, mapModel, mapMsg

#Advanced Mapping

@docs map2Model, applyExternalMsg, sequence


# Consuming

@docs resolve, resolveError, resolveModel

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


{-| Transform a `ComponentResult`'s model, if it exists (i.e. it is not a [`justError`](#justError))
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


{-| Given a list of transformation of a model to a ComponentResult (which may result in errors or
require `Cmd msg` dispatches\`, fold over all transformations given a starting model.
-}
sequence : List (model -> ComponentResult model msg Never err) -> model -> ComponentResult model msg externalMsg err
sequence updaters model =
    updaters
        |> List.foldl
            (\updater result ->
                case result of
                    ModelAndCmd model_ cmd ->
                        updater model_ |> withCmd cmd

                    ModelAndExternal _ aNever _ ->
                        never aNever

                    JustError err ->
                        JustError err
            )
            (withModel model)
        |> (\result ->
                case result of
                    ModelAndCmd model_ cmd ->
                        ModelAndCmd model_ cmd

                    ModelAndExternal _ aNever _ ->
                        never aNever

                    JustError err ->
                        JustError err
           )


{-| Given a function which can use an externalMsg, and a ComponentResult with no external msg,
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


{-| Given a `ComponentResult` with no Cmd, error or external message, transform it into a model.
-}
resolveModel : ComponentResult model Never Never Never -> model
resolveModel result =
    case result of
        ModelAndCmd model _ ->
            model

        ModelAndExternal _ aNever _ ->
            never aNever

        JustError aNever ->
            never aNever
