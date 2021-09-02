//
//  ImageModel.m
//  UserInterfaceExample
//
//  Created by Eric Larson on 9/2/20.
//  Copyright © 2020 Eric Larson. All rights reserved.
//

#import "ImageModel.h"

@interface ImageModel()

@property (strong, nonatomic) NSMutableDictionary* imagesMap;
@property (strong, nonatomic) NSArray* imageNames;


@end

@implementation ImageModel

//@synthesize imageNames = _imageNames;
//@synthesize imageNames = _imageNames;

+(ImageModel*)sharedInstance{
    
    
    static ImageModel* _sharedInstance = nil;
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        _sharedInstance = [[ImageModel alloc] init];
    } );
    
    return _sharedInstance;
}


-(NSArray*) imageNames{
    if(!_imageNames)
        _imageNames = @[@"Bill",@"Eric",@"Jeff", @"image1",@"image2",@"image3"];
    return _imageNames;
}


-(UIImage*)getImageWithName:(NSString*)name{
    UIImage* image = nil;
    image = [UIImage imageNamed:name];
    return image;
}


// for labs:
-(UIImage*)getImageWithIndex:(NSInteger)index{
    UIImage* image = nil;
    NSString* name = self.imageNames[index];
    image = self.imagesMap[name];
    return image;
}



-(UIImage*)readImage:(NSString*)name{
    UIImage* loadedImage = [UIImage imageNamed:name];
    return loadedImage;
}

-(NSDictionary*)imagesMap{
    if(!_imagesMap){
        _imagesMap = [@{} mutableCopy];
        _imagesMap[@"Bill"] = [self readImage: @"Bill"];
        _imagesMap[@"Eric"] = [self readImage: @"Eric"];
        _imagesMap[@"Jeff"] = [self readImage: @"Jeff"];
        _imagesMap[@"image1"] = [self readImage: @"image1"];
        _imagesMap[@"image2"] = [self readImage: @"image2"];
        _imagesMap[@"image3"] = [self readImage: @"image3"];
    }
    return _imagesMap;
}


-(NSInteger)numberOfImages{
    return self.imagesMap.count;
}


-(NSString*)getImageNameForIndex:(NSInteger)index{
    if(index < [self numberOfImages]){
        return self.imageNames[index];
    }
    return @"NULL";
}




@end
