#!/usr/bin/python

from pymongo import MongoClient
import tornado.web

from tornado.web import HTTPError
from tornado.httpserver import HTTPServer
from tornado.ioloop import IOLoop
from tornado.options import define, options

from basehandler import BaseHandler

import turicreate as tc
import pickle
from bson.binary import Binary
import json
import numpy as np
import base64

from PIL import Image, ImageOps
import io
from matplotlib import pyplot as plt

class PrintHandlers(BaseHandler):
    def get(self):
        '''Write out to screen the handlers used
        This is a nice debugging example!
        '''
        self.set_header("Content-Type", "application/json")
        self.write(self.application.handlers_string.replace('),','),\n'))

class UploadLabeledDatapointHandler(BaseHandler):
    def post(self):
        '''Save data point and class label to database
        '''
        data = json.loads(self.request.body.decode("utf-8"))

        fvals = data['feature']
        # convert base64 image to np array and grayscale it
        image = Image.open(io.BytesIO(base64.b64decode(fvals)))
        image = ImageOps.grayscale(image)
        image_np = np.array(image)
        image_arr = image_np.tolist()
        label = data['label']
        sess  = data['dsid']
        dbid = self.db.labeledinstances.insert(
            {"feature":image_arr,"label":label,"dsid":sess}
            );
        self.write_json({"id":str(dbid),
            "feature":"done",
            "label":label})

class RequestNewDatasetId(BaseHandler):
    def get(self):
        '''Get a new dataset ID for building a new dataset
        '''
        a = self.db.labeledinstances.find_one(sort=[("dsid", -1)])
        if a == None:
            newSessionId = 1
        else:
            newSessionId = float(a['dsid'])+1
        self.write_json({"dsid":newSessionId})

class UpdateUserChosenModelForDatasetId(BaseHandler):
    def post(self):
        '''Train a new user specified model (or update) for given dataset ID
        '''
        post_payload = json.loads(self.request.body.decode("utf-8"))    

        dsid = post_payload["dsid"]
        model_type = post_payload["modelType"]

        data = self.get_features_and_labels_as_SFrame(dsid)

        # fit the model to the data
        acc = -1
        if len(data)>0:
            max_iterations = post_payload["maxIterations"] #int stepper
            if (model_type == "BTC"):
                model = tc.boosted_trees_classifier.create(data,target='target',verbose=0, max_iterations=max_iterations) # Training a Boosted Trees Classifier
            elif(model_type == "LC"):
                model = tc.logistic_classifier.create(data, target='target', verbose = 0, max_iterations=max_iterations) # Training an Logistic Classifier
            elif(model_type == "best"):
                model = tc.classifier.create(data,target='target',verbose=0) # Creating and training the best classifier
            
            yhat = model.predict(data)
            self.clf[dsid] = model
            acc = sum(yhat==data['target'])/float(len(data))
            print("this is the accuracy: ", acc)
            print('../models/turi_model_%s_dsid_%d'%(model_type, dsid))
            model.save('../models/turi_model_%s_dsid_%d'%(model_type, dsid))
            self.write_json({"resubAccuracy":str(acc)})
        else:
            raise HTTPError(404)
        

    def get_features_and_labels_as_SFrame(self, dsid):
        # create feature vectors from database
        features=[]
        labels=[]
        count = 0
        for a in self.db.labeledinstances.find({"dsid":dsid}): 
            features.append(a['feature'])
            labels.append(a['label'])
            count += 1

        # convert to dictionary for tc
        data = {'target':labels, 'sequence':np.array(features)}

        # send back the SFrame of the data
        return tc.SFrame(data=data)

class PredictOneFromChosenModelDatasetId(BaseHandler):
    def post(self):
        '''Predict the class of a sent feature vector
        '''
        data = json.loads(self.request.body.decode("utf-8"))    
        fvals = self.get_features_as_SFrame(data['feature'])
        dsid  = data['dsid']
        model_type = data["modelType"]

        # load the model from the database (using pickle)
        # we are blocking tornado!! no!!
        if self.clf == {} or dsid in self.clf:
            print('Loading Model From file')
            try: 
                print('../models/turi_model_%s_dsid_%d'%(model_type, dsid))
                self.clf[dsid] = tc.load_model('../models/turi_model_%s_dsid_%d'%(model_type, dsid))
            except: 
                raise HTTPError(404)
            predLabel = self.clf[dsid].predict(fvals)
            self.write_json({"prediction":str(predLabel[0])})
        else:
            raise HTTPError(404)

    def get_features_as_SFrame(self, vals):
        # create feature vectors from array input
        # convert to dictionary of arrays for tc

        # convert base64 image to np array and grayscale it
        image = Image.open(io.BytesIO(base64.b64decode(vals)))
        image = ImageOps.grayscale(image)
        image_np = np.array(image)

        image_arr = image_np.tolist()
        test = np.array([image_arr])
        data = {'sequence':test}
        df = tc.SFrame(data=data)

        # send back the SFrame of the data
        return df

class ExportHandler(BaseHandler):
    def get(self):
        '''Export Model for a given DSID
        '''
        dsid = self.get_int_arg("dsid",default=0)

        # load the model from the database (using pickle)
        if self.clf == {} or dsid in self.clf:
            print('Loading Model From file')
            try: 
                self.clf[dsid] = tc.load_model('../models/turi_model_best_dsid_%d'%(dsid))
                self.clf[dsid].export_coreml("mymodel.mlmodel")
            except: 
                raise HTTPError(404)
            self.write_json({"success":"hellyeah"})
        else:
            raise HTTPError(404)