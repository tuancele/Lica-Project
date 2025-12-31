<?php
namespace Modules\IAM\Models;
use Illuminate\Database\Eloquent\Model;

class District extends Model
{
    protected $primaryKey = 'code';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];

    public function province() {
        return $this->belongsTo(Province::class, 'province_code', 'code');
    }
    public function wards() {
        return $this->hasMany(Ward::class, 'district_code', 'code');
    }
}
