module Main exposing (main)

{- This is a starter app which presents a text label, text field, and a button.
   What you enter in the text field is echoed in the label.  When you press the
   button, the text in the label is reverse.
   This version uses `mdgriffith/elm-ui` for the view functions.
-}

import Browser
import CellGrid exposing (CellGrid, Dimensions, Position)
import CellGrid.Render exposing (CellStyle, Msg)
import Color
import Conway exposing (State(..))
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Random
import Time exposing (Posix)

type alias Config = {
  tickInterval : Float
  , initialDensity : Float
  , initialSeed : Int
  , gridWidth : Int
  , gridDisplayWidth : Float
  , lowDensityThreshold : Float
  }

config : Config
config = {
  tickInterval = 100
  , initialDensity = 0.3
  , initialSeed = 3771
  , gridWidth = 100
  , gridDisplayWidth = 420
  , lowDensityThreshold = 0.0
  }





main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { input : String
    , output : String
    , counter : Int
    , trial : Int
    , appState : AppState
    , density : Float
    , gridWidth : Int
    , densityString : String
    , gridWidthString : String
    , currentDensity : Float
    , seed : Int
    , seedString : String
    , randomPosition : Position
    , cellMap : CellGrid State
    , message : String
    }


type AppState
    = Ready
    | Running
    | Paused



--
-- MSG
--


type Msg
    = NoOp
    | InputBeta String
    | InputSeed String
    | InputGridWidth String
    | Step
    | Tick Posix
    | AdvanceAppState
    | Reset
    | NewPosition Position
    | CellGrid CellGrid.Render.Msg


type alias Flags =
    {}


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { input = "Test"
      , output = "Test"
      , counter = 0
      , trial = 0
      , appState = Ready
      , density = config.initialDensity
      , densityString = String.fromFloat config.initialDensity
      , gridWidth = config.gridWidth
      , gridWidthString = String.fromInt config.gridWidth
      , currentDensity = config.initialDensity
      , seed = config.initialSeed
      , seedString = String.fromInt config.initialSeed
      , randomPosition = Position 0 0
      , cellMap = initialCellGrid config.initialSeed config.initialDensity
      , message = "Click to make cell."
      }
    , Cmd.none
    )


initialCellGrid : Int -> Float -> CellGrid State
initialCellGrid seed density =
    Conway.new seed density (Dimensions config.gridWidth  config.gridWidth)


subscriptions model =
    Time.every config.tickInterval Tick


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        InputBeta str ->
            case String.toFloat str of
                Nothing ->
                    ( { model | densityString = str }, Cmd.none )

                Just density_ ->
                    ( { model | densityString = str, density = density_ }, Cmd.none )


        InputGridWidth str ->
                    case String.toInt str of
                        Nothing ->
                            ( { model | gridWidthString = str }, Cmd.none )

                        Just gridWidth_ ->
                            let
                              (gridWidthString__, gridWidth__) =
                                  if gridWidth_ <= 100 then
                                     (str, gridWidth_)
                                  else
                                    ("100", 100)
                              newModel = { model | gridWidthString = gridWidthString__, gridWidth =  gridWidth__ }
                            in
                              reset newModel

        InputSeed str ->
            case String.toInt str of
                Nothing ->
                    ( { model | seedString = str }, Cmd.none )

                Just seed_ ->
                    ( { model | seedString = str, seed = seed_ }, Cmd.none )

        Step ->
            ( { model | counter = model.counter + 1, cellMap = Conway.step model.cellMap }, Cmd.none )

        Tick t ->
            case model.appState == Running of
                True ->
                    ( { model
                        | counter = model.counter + 1
                        , cellMap = Conway.step model.cellMap |> generateNewLife model
                        , currentDensity = currentDensity model
                      }
                    , Random.generate NewPosition (generatePosition model)
                    )

                False ->
                    ( model, Cmd.none )

        AdvanceAppState ->
            let
                nextAppState =
                    case model.appState of
                        Ready ->
                            Running

                        Running ->
                            Paused

                        Paused ->
                            Running
            in
            ( { model | appState = nextAppState }, Cmd.none )

        Reset ->
            reset model

        NewPosition position ->
            ( { model | randomPosition = position }, Cmd.none )

        CellGrid cellMsg ->
            let
                i =
                    cellMsg.cell.row

                j =
                    cellMsg.cell.column

                message =
                    "(i,j) = (" ++ String.fromInt i ++ ", " ++ String.fromInt j ++ ")"
            in
            ( { model
                | message = message
                , cellMap = Conway.toggleStateAt (Position i j) model.cellMap
              }
            , Cmd.none
            )


reset model =
    ( { model
        | counter = 0
        , trial = model.trial + 1
        , appState = Ready
        , cellMap = initialCellGrid (model.seed + model.trial + 1) model.density
      }
    , Cmd.none
    )

generateNewLife : Model -> CellGrid State -> CellGrid State
generateNewLife model cg =
    case model.currentDensity < config.lowDensityThreshold of
        False ->
            cg

        True ->
            Conway.occupy model.randomPosition cg


generatePosition : Model -> Random.Generator Position
generatePosition model =
    Random.map2 Position (Random.int 0 ( model.gridWidth - 1)) (Random.int 0 ( model.gridWidth - 1))



--
-- VIEW
--


view : Model -> Html Msg
view model =
    Element.layout [ Background.color dark ] (mainColumn model)


mainColumn : Model -> Element Msg
mainColumn model =
    column mainColumnStyle
        [ column [ centerX, spacing 20 ]
            [ title <| "Conway's Game of Life (" ++ String.fromInt  model.gridWidth ++ ", " ++ String.fromInt  model.gridWidth ++ ")"
            , el [ centerX ]
                (CellGrid.Render.asHtml { width = round config.gridDisplayWidth, height = round config.gridDisplayWidth } (cellStyle model) model.cellMap
                    |> Element.html
                    |> Element.map CellGrid
                )
            , row [ spacing 18 ]
                [ resetButton
                , runButton model
                , row [ spacing 8 ] [ stepButton, counterDisplay model ]
                , inputDensity model
                , inputGridSize model
                ]
            , row [ Font.size 14, centerX, spacing 24 ]
                [ el [ width (px 150), Font.color light ] (text <| "Current density = " ++ String.fromFloat model.currentDensity)
                , Element.newTabLink [ Font.size 14, centerX, Font.color <| Element.rgb 0.4 0.4 1 ]
                    { url = "https://github.com/jxxcarlson/elm-cell-grid/tree/master/examples/GameOfLife"
                    , label = el [] (text "Code on GitHub")
                    }
                , el [ width (px 100), Font.color light ] (text <| model.message)
                ]
            ]
        ]


currentDensity : Model -> Float
currentDensity model =
    let
        population =
            Conway.occupied model.cellMap |> toFloat

        capacity =
             config.gridWidth *  config.gridWidth |> toFloat
    in
    population / capacity |> roundTo 2


roundTo : Int -> Float -> Float
roundTo places x =
    let
        k =
            10 ^ places |> toFloat
    in
    (round (k * x) |> toFloat) / k



cellStyle : Model -> CellStyle State
cellStyle model =
    { toColor =
        \b ->
            case b of
                Occupied ->
                    Color.rgb 0.0 0.0 0.9

                Unoccupied ->
                    Color.rgb 0.0 0.0 0.3

    , cellWidth = config.gridDisplayWidth / (toFloat model.gridWidth)
    , cellHeight = config.gridDisplayWidth / (toFloat model.gridWidth)
    , gridLineWidth = 0.5
    , gridLineColor = Color.rgb 0.2 0.2 0.3
    }


counterDisplay : Model -> Element Msg
counterDisplay model =
    el [ Font.size 18, width (px 30), Font.color light ] (text <| String.fromInt model.counter)


title : String -> Element msg
title str =
    row [ centerX, Font.bold, Font.color light ] [ text str ]


outputDisplay : Model -> Element msg
outputDisplay model =
    row [ centerX ]
        [ text model.output ]


buttonFontSize =
    16


inputDensity : Model -> Element Msg
inputDensity model =
    Input.text [ width (px 60), height (px 30), Font.size buttonFontSize, Background.color light ]
        { onChange = InputBeta
        , text = model.densityString
        , placeholder = Nothing
        , label = Input.labelLeft [] <| el [ Font.size buttonFontSize, moveDown 8.5, Font.color light ] (text "Initial density ")
        }

inputGridSize : Model -> Element Msg
inputGridSize model =
    Input.text [ width (px 60), height (px 30), Font.size buttonFontSize, Background.color light ]
        { onChange = InputGridWidth
        , text = model.gridWidthString
        , placeholder = Nothing
        , label = Input.labelLeft [] <| el [ Font.size buttonFontSize, moveDown 8.5, Font.color light ] (text "Grid size ")
        }


inputSeed : Model -> Element Msg
inputSeed model =
    Input.text [ width (px 60), Font.size buttonFontSize ]
        { onChange = InputSeed
        , text = model.seedString
        , placeholder = Nothing
        , label = Input.labelLeft [] <| el [ Font.size buttonFontSize, moveDown 12 ] (text "seed ")
        }


stepButton : Element Msg
stepButton =
    row [ centerX ]
        [ Input.button buttonStyle
            { onPress = Just Step
            , label = el [ centerX, centerY ] (text "Step")
            }
        ]


runButton : Model -> Element Msg
runButton model =
    row [ centerX, width (px 80) ]
        [ Input.button (buttonStyle ++ [ activeBackgroundColor model ])
            { onPress = Just AdvanceAppState
            , label = el [ centerX, centerY, width (px 60) ] (text <| appStateAsString model.appState)
            }
        ]


activeBackgroundColor model =
    case model.appState of
        Running ->
            Background.color (Element.rgb 0.65 0 0)

        _ ->
            Background.color (gray 0.2)


resetButton : Element Msg
resetButton =
    row [ centerX ]
        [ Input.button buttonStyle
            { onPress = Just Reset
            , label = el [ centerX, centerY ] (text <| "Reset")
            }
        ]


appStateAsString : AppState -> String
appStateAsString appState =
    case appState of
        Ready ->
            "Run"

        Running ->
            "Running"

        Paused ->
            "Paused"



--
-- STYLE
--


dark =
    gray 0.1


light =
    gray 0.8


gray g =
    rgb g g g


mainColumnStyle =
    [ centerX
    , centerY
    , Background.color dark
    , paddingXY 20 20
    ]


buttonStyle =
    [ Background.color (gray 0.2)
    , Font.color (gray 0.7)
    , paddingXY 15 8
    , Font.size buttonFontSize
    ]



--
