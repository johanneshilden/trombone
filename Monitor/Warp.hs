{-# LANGUAGE RecordWildCards #-}
module Monitor.Warp 
    ( sigServ
    , ServerSettings(..)
    , Shutdown(..)
    ) where

import Control.Concurrent                ( forkIO, killThread, threadDelay )
import Control.Concurrent.STM
import Control.Exception                 ( SomeException, AsyncException(..), fromException, try, throw )
import Control.Monad                     ( when, liftM, join, void )
import Control.Monad.Trans               ( liftIO )
import Data.Typeable
import Network.Wai
import Network.Wai.Handler.Warp
import System.Posix.Signals              ( installHandler, Handler(Catch), sigHUP, sigTERM, fullSignalSet )

data Shutdown = Exit | Restart
    deriving (Eq, Show)

-- | This function "wraps" around the original request handler to allow 
-- more graceful shutdown and restart operations.
proxy :: a -> TMVar Shutdown -> Application -> Response -> Application
proxy options shutdown handler message req resp = 
    join . atomically $ do
        -- Check if a shutdown/restart has been initiated
        shouldRun <- isEmptyTMVar shutdown
        return $ if shouldRun
            then handler req resp
            -- If the TMVar is full, we're shutting down
            else resp message

-- | Server configuration
data ServerSettings a = ServerSettings
    { handler  :: Application      -- ^ Client's request handler
    , config   :: Settings         -- ^ Warp server settings
    , response :: Response         -- ^ A response to return during shutdown
    , options  :: a                -- ^ Arbitrary client application data passed 
    }                             --   to shutdown handler.

-- | Introduces some process management capabilities to the Warp server via
-- SIGHUP and SIGTERM. This function launches the server as a monitored worker 
-- thread and installs the necessary signal handlers.
sigServ :: IO (ServerSettings a)      
        -- ^ Called prior to server start
        -> (ServerSettings a -> Shutdown -> IO ()) 
        -- ^ Shutdown hook. Accepts the settings object and a value to indicate
        -- the type of shutdown operation imminent (exit or restart).
        -> IO ()
sigServ onUp onDown = do

    shutdown <- newEmptyTMVarIO
    conns <- newTVarIO (0 :: Int)

    installHandler sigHUP  (Catch $ hup  shutdown) (Just fullSignalSet)
    installHandler sigTERM (Catch $ term shutdown) (Just fullSignalSet)

    runWorker shutdown conns 

  where
    runWorker :: TMVar Shutdown -> TVar Int -> IO ()
    runWorker shutdown conns = do
    
        settings@ServerSettings{..} <- onUp
    
        -- Install hooks to keep track of the number of open connections
        let settings' = setOnOpen  (onOpen  conns)
                      $ setOnClose (onClose conns)
                        config

        worker <- forkIO $ do
            r <- try $ runSettings settings' (proxy options shutdown handler response)
            case r of
                Left e -> do
                    print (e :: SomeException)
                    -- An exception typically happens if the port is already in use
                    case fromException e of
                        Just ThreadKilled -> return ()
                        -- Shut down immediately
                        _ -> atomically $ putTMVar shutdown Exit 
                Right r -> return r
    
        action <- monitor shutdown conns
    
        -- The worker is taken down, in case we intend to restart the service
        killThread worker
    
        onDown settings action
    
        -- If a SIGHUP was received, we reload any configuration
        -- files, re-initialize the server and fork a new thread
        when (Restart == action) $ do
            threadDelay 2000 -- Sleep for 0.002 secs.
            runWorker shutdown conns 

-- | Wait for the worker thread to signal exit via the TMVar synchronization 
-- primitive and then block until all outstanding requests have completed.
-- The function returns one of the two Shutdown constructors to indicate the 
-- type of shutdown, viz., Exit or Restart.
monitor :: TMVar Shutdown -> TVar Int -> IO Shutdown
monitor shutdown conns = atomically $ do
    var <- takeTMVar shutdown
    conns <- readTVar conns
    when (conns /= 0) 
        retry
    return var

hup :: TMVar Shutdown -> IO ()
{-# INLINE hup #-}
hup tvar = do
    putStrLn "SIGHUP"
    atomically $ putTMVar tvar Restart

term :: TMVar Shutdown -> IO ()
{-# INLINE term #-}
term tvar = do
    putStrLn "SIGTERM"
    atomically $ putTMVar tvar Exit

modify :: TVar a -> (a -> a) -> IO ()
{-# INLINE modify #-}
modify tvar = atomically . modifyTVar' tvar

onOpen :: Num a => TVar a -> t -> IO Bool
{-# INLINE onOpen #-}
onOpen tvar _  = modify tvar (+1) >> return True

onClose :: Num a => TVar a -> t -> IO ()
{-# INLINE onClose #-}
onClose tvar _ = modify tvar (subtract 1) 

