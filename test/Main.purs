module Test.Jaeger.Main where

import Prelude

import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldSatisfy)
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner (runSpec)
import Yoga.Jaeger.Jaeger as Jaeger

spec :: Spec Unit
spec = do
  describe "Yoga.Jaeger FFI" do
    describe "Basic Types" do
      it "creates service name" do
        let svc = Jaeger.ServiceName "test-service"
        pure unit

main :: Effect Unit
main = launchAff_ $ runSpec [ consoleReporter ] spec
