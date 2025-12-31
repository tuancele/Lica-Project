<?php
namespace Modules\IAM\Models;
use Illuminate\Database\Eloquent\Model;

class Province extends Model
{
    protected $primaryKey = 'code';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];

    public function districts() {
        return $this->hasMany(District::class, 'province_code', 'code');
    }
}
