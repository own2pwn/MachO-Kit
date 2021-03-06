//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKCString.m
//|
//|             D.V.
//|             Copyright (c) 2014-2015 D.V. All rights reserved.
//|
//| Permission is hereby granted, free of charge, to any person obtaining a
//| copy of this software and associated documentation files (the "Software"),
//| to deal in the Software without restriction, including without limitation
//| the rights to use, copy, modify, merge, publish, distribute, sublicense,
//| and/or sell copies of the Software, and to permit persons to whom the
//| Software is furnished to do so, subject to the following conditions:
//|
//| The above copyright notice and this permission notice shall be included
//| in all copies or substantial portions of the Software.
//|
//| THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//| OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//| MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//| IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//| CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//| TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//| SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------------//

#import "MKCString.h"
#import "NSError+MK.h"

//----------------------------------------------------------------------------//
@implementation MKCString

@synthesize string = _string;

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithOffset:(mk_vm_offset_t)offset fromParent:(MKBackedNode *)parent error:(NSError **)error
{
    self = [super initWithOffset:offset fromParent:parent error:error];
    if (self == nil) return nil;
    
    // CStrings are NULL terminated and we are given no indication of the
    // string's length.
    
    // The provided offset must be within the range of our parent node.
    mk_error_t err;
    mk_vm_range_t parentRange = mk_vm_range_make(parent.nodeContextAddress, parent.nodeSize);
    if ((err = mk_vm_range_contains_address(parentRange, offset, parent.nodeContextAddress))) {
        MK_ERROR_OUT = [NSError mk_errorWithDomain:MKErrorDomain code:MK_ENOT_FOUND description:@"Provided offset %" MK_VM_PRIiOFFSET " is not within the parent node %@", offset, parent];
        [self release]; return nil;
    }
    
    _nodeSize = parent.nodeSize - offset;
    __block NSError *localError = nil;
    
    [parent.memoryMap remapBytesAtOffset:offset fromAddress:parent.nodeContextAddress length:_nodeSize requireFull:NO withHandler:^(vm_address_t address, vm_size_t length, NSError *e) {
        if (length == 0 || e) {
            localError = e;
            return;
        }
        
        _nodeSize = strnlen((const char*)address, length);
        _string = [[NSString alloc] initWithBytes:(const void*)address length:(NSUInteger)_nodeSize encoding:NSUTF8StringEncoding];
        
        if (_string == nil)
            MK_PUSH_WARNING(MK_PROPERTY(string), MK_EINVALID_DATA, @"Failed to create string with bytes.");
        
        if (_nodeSize < length) {
            // Account for the NULL byte.
            _nodeSize = _nodeSize + 1;
        } else {
            MK_PUSH_WARNING(MK_PROPERTY(sring), MK_EINVALID_DATA, @"String not properly terminated.");
        }
    }];
    
    if (localError) {
        MK_ERROR_OUT = localError;
        [self release]; return nil;
    }
    
    return self;
}

//|++++++++++++++++++++++++++++++++++++|//
- (void)dealloc
{
    [_string release];
    [super dealloc];
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark - MKNode
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (mk_vm_size_t)nodeSize
{ return _nodeSize; }

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        [MKNodeField nodeFieldWithProperty:MK_PROPERTY(string) description:@"Value"]
    ]];
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark - NSObject
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (NSString*)description
{ return _string; }

//|++++++++++++++++++++++++++++++++++++|//
- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:MKCString.class])
        return [[object string] isEqualToString:self.string];
    else if ([object isKindOfClass:NSString.class])
        return [object isEqualToString:self.string];
    else
        return NO;
}

//|++++++++++++++++++++++++++++++++++++|//
- (NSUInteger)hash
{ return self.string.hash; }

@end
