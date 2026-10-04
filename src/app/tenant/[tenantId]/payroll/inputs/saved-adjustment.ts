// CAS compares immutable JSON, including number/string and optional-field types.
// Preserve an unchanged saved primitive; never discard an edited visible value.
export function retainedAdjustmentData(values:Record<string,string>,saved?:Record<string,string|boolean|number>) {
 const result:Record<string,string|boolean|number>={...values};
 for(const [key,value] of Object.entries(saved??{}))if(String(value)===(values[key]??''))result[key]=value;
 return result;
}
