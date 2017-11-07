#!/usr/bin/env groovy

@Library('jenkins-shared') _

pipeline {
    agent any
    stages {
        stage('Prepare Environment') {
            steps {
                setBuildName()
                connectToECR()
            }
        }
        stage('Test with Latest StableJulia') {
            steps {
                runUnitTestJulia()
            }
        }
    }
}

