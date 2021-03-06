module App.Brick.Types
  (
    AppState(..)
  , Timestamped
  , LogLvl(..)
  , LogMsg(..)
  , Name
  , AppWorkingArea(..)

  , areaLockedToCurrentWork

  , initAppState
  , module App.Types.Core
  ) where

import qualified Brick.Widgets.Dialog as Bk
import           Control.Concurrent
import qualified Data.Sequence as Seq
import qualified Data.Text as T
import qualified Data.Time.Clock as Time

import qualified SyncState as SS
import qualified SyncStrategy as SStrat

import           App.Types.Core

-- | the UI state
type Timestamped a = (Time.UTCTime, a)

data AppState = AppState
  {
    appConfig :: AppConfig
  -- ^ needed for rendering, but should never change during app run
  , appActionHistory :: Seq.Seq (Timestamped SS.SyncAction')
  , appLogs :: Seq.Seq (Timestamped LogMsg)
  -- ^ these are currently queues in memory
  -- TODO: make the queues bounded in some ways
  , appMsgQueue :: Seq.Seq AppMsg
  -- ^ accumulated msgs while we are dealing with something else
  , appWorkingArea :: AppWorkingArea
  -- ^ the current item waiting for a response
  }

data LogLvl = Log | Warn | Error deriving (Show, Eq, Enum, Bounded)
data LogMsg = LogMsg
  { logLvl :: LogLvl
  , logMsg :: T.Text
  } deriving (Show, Eq)

type Name = ()

data AppWorkingArea = AreaSyncPlansResolveConflict
                      { areaOriginalPlans    :: [SS.SyncPlan']
                      , areaPendingActions   :: [SS.SyncAction']
                      , areaPendingConflicts :: [SS.SyncConflict']

                      , areaCurrentConflict  :: SS.SyncConflict'
                      -- ^ the current conflict to resolve with user
                      , areaStrategyChoice   :: Bk.Dialog SStrat.SyncStrategy
                      -- ^ user options to resolve the conflict
                      , areaReplyMVar        :: MVar [SS.SyncAction']
                      }
                    | AreaSyncPlansWaitPerform
                      { areaOriginalPlans     :: [SS.SyncPlan']
                      , areaPerformingActions :: [SS.SyncAction']
                      }
                    | AreaSyncActionsPerformed
                      { areaOriginalPlans    :: [SS.SyncPlan']
                      , areaPerformedActions :: [SS.SyncAction']
                      }
                    | AreaAlertMsg
                      { areaAlertMsg :: LogMsg
                      }
                    | AreaNoWork -- nothing outstanding

instance Monoid AppWorkingArea where
  mempty = AreaNoWork
  a `mappend` AreaNoWork = a
  AreaNoWork `mappend` a = a
  x `mappend` _ = x

-- | Determines whether the working area can be open for use on new task
areaLockedToCurrentWork :: AppWorkingArea -> Bool
areaLockedToCurrentWork AreaNoWork = False
areaLockedToCurrentWork AreaSyncPlansWaitPerform{} = False
areaLockedToCurrentWork AreaSyncActionsPerformed{} = False
areaLockedToCurrentWork AreaAlertMsg{} = True
areaLockedToCurrentWork AreaSyncPlansResolveConflict{} = True

initAppState
  :: AppConfig
  -> AppState
initAppState conf = AppState
  { appConfig = conf
  , appActionHistory = mempty
  , appLogs = mempty
  , appMsgQueue = mempty
  , appWorkingArea = mempty
  }
